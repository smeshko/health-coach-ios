import Foundation

/// A serial, best-effort log-file appender with size+count rotation, living under `Caches/Logs/`.
///
/// **Serial + non-blocking + deterministic flush** (PLAN Risk 2): writes are funnelled through a
/// single `AsyncStream` consumed by one actor-isolated loop, so lines never interleave. `enqueue(_:)`
/// is synchronous and non-blocking — it only `yield`s onto the stream, so the request/UI thread never
/// waits on file I/O. `flush()` yields a FIFO sentinel and awaits it: because the stream is processed
/// in order, every previously-enqueued write has completed by the time `flush()` returns, which is
/// what makes the fire-and-forget writes deterministically observable in host tests.
///
/// The file under `Caches/` may be purged by the OS — acceptable for debug logs. The 7.4 log viewer
/// reads `currentFileURL` (+ the rotated siblings in `directory`).
public actor LogFileWriter {
  /// ~1 MB per file before rotating.
  public static let defaultMaxBytes = 1_048_576
  /// Keep at most this many files (current + rotated).
  public static let defaultMaxFiles = 5

  /// The default on-disk location: `<Caches>/Logs/`.
  public static var defaultDirectory: URL {
    let base = (try? FileManager.default.url(
      for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false
    )) ?? FileManager.default.temporaryDirectory
    return base.appendingPathComponent("Logs", isDirectory: true)
  }

  /// The process-wide writer the live `LogClient` shares across emitters, so every entry appends to
  /// one file with one rotation counter (separate writers over the same path would corrupt each
  /// other).
  public static let shared = LogFileWriter(directory: defaultDirectory)

  private enum Command: Sendable {
    case write(String)
    case flush(@Sendable () -> Void)
    case clear(@Sendable () -> Void)
  }

  private let directory: URL
  private let maxBytes: Int
  private let maxFiles: Int
  private let fileManager = FileManager.default
  private let continuation: AsyncStream<Command>.Continuation

  private var fileIndex = 0
  private var currentSize = 0

  public init(
    directory: URL,
    maxBytes: Int = LogFileWriter.defaultMaxBytes,
    maxFiles: Int = LogFileWriter.defaultMaxFiles
  ) {
    self.directory = directory
    self.maxBytes = max(1, maxBytes)
    self.maxFiles = max(1, maxFiles)
    let (stream, continuation) = AsyncStream<Command>.makeStream()
    self.continuation = continuation
    Task { [weak self] in
      for await command in stream {
        guard let self else { break }
        await handle(command)
      }
    }
  }

  /// The file currently being appended to. Rotated siblings sit alongside it in `directory`.
  public var currentFileURL: URL {
    directory.appendingPathComponent("coach-\(fileIndex).log")
  }

  /// Recent log lines across the current file + rotated siblings, in chronological order
  /// (oldest→newest), capped to the **last** `maxLines`. Actor-isolated, so it never interleaves with
  /// an in-flight append (the writes funnel through the same actor). Best-effort: an unreadable or
  /// missing file is skipped. Backs the Phase 7.4 DEBUG log viewer via `LogClient.readRecent`.
  public func recentLines(maxLines: Int = 2000) -> [String] {
    let urls = ((try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
      .filter { $0.pathExtension == "log" && $0.lastPathComponent.hasPrefix("coach-") }
      .sorted { Self.rotationIndex($0) < Self.rotationIndex($1) }

    var lines: [String] = []
    for url in urls {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      lines.append(contentsOf: text.split(separator: "\n").map(String.init))
    }
    return Array(lines.suffix(maxLines))
  }

  /// The rotation index parsed out of a `coach-<n>.log` URL (so the files concatenate in write order).
  /// Unparseable names sort first.
  private static func rotationIndex(_ url: URL) -> Int {
    Int(url.deletingPathExtension().lastPathComponent.dropFirst("coach-".count)) ?? -1
  }

  /// Enqueue a line for appending — synchronous and non-blocking (off the caller's thread).
  public nonisolated func enqueue(_ line: String) {
    continuation.yield(.write(line))
  }

  /// Await until every line enqueued **before** this call has been written. Test-only determinism
  /// seam; the request path never calls it.
  public nonisolated func flush() async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      continuation.yield(.flush { cont.resume() })
    }
  }

  /// Delete every persisted log file and reset the rotation counter — backs `LogClient.clear` (the
  /// DEBUG log viewer's "Clear" action). Routed through the same FIFO stream as the writes, so it is
  /// ordered **after** every line enqueued before it (a clear truly clears what was just logged) and
  /// never interleaves with an in-flight append.
  public nonisolated func clear() async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      continuation.yield(.clear { cont.resume() })
    }
  }

  private func handle(_ command: Command) {
    switch command {
    case let .write(line):
      write(line)
    case let .flush(signal):
      signal()
    case let .clear(signal):
      removeAllFiles()
      signal()
    }
  }

  /// Remove every `coach-*.log` file and reset the rotation state so the next write starts fresh at
  /// `coach-0.log`. Best-effort: an undeletable file is skipped.
  private func removeAllFiles() {
    let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    for url in urls where url.pathExtension == "log" && url.lastPathComponent.hasPrefix("coach-") {
      try? fileManager.removeItem(at: url)
    }
    fileIndex = 0
    currentSize = 0
  }

  private func write(_ line: String) {
    let data = Data((line + "\n").utf8)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    let url = currentFileURL
    if !fileManager.fileExists(atPath: url.path) {
      fileManager.createFile(atPath: url.path, contents: nil)
      currentSize = 0
    }
    guard let handle = try? FileHandle(forWritingTo: url) else { return } // best-effort
    defer { try? handle.close() }
    do {
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
      currentSize += data.count
    } catch {
      return // never throw into the caller
    }

    if currentSize >= maxBytes {
      rotate()
    }
  }

  private func rotate() {
    fileIndex += 1
    currentSize = 0
    pruneOldFiles()
  }

  /// Delete every file older than the newest `maxFiles` (indices `fileIndex - maxFiles + 1 ... fileIndex`).
  private func pruneOldFiles() {
    let oldestToKeep = fileIndex - maxFiles + 1
    guard oldestToKeep > 0 else { return }
    for index in 0 ..< oldestToKeep {
      let url = directory.appendingPathComponent("coach-\(index).log")
      try? fileManager.removeItem(at: url)
    }
  }
}
