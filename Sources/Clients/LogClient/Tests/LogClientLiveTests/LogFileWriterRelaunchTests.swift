import Foundation
import Testing

@testable import LogClientLive

// Phase 20.4: rotation state must survive a relaunch. Every test simulates a restart by pointing a
// brand-new `LogFileWriter` instance at a directory a previous instance (or a pre-seeded file)
// already wrote to. Parallel-safe: each test uses its own UUID-suffixed temp directory.
struct LogFileWriterRelaunchTests {
  /// A throwaway temp directory cleaned up after each test.
  private func tempDirectory(_ name: String = #function) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("LogFileWriterRelaunchTests-\(name)-\(UUID().uuidString)", isDirectory: true)
  }

  private func contents(of url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }

  /// A new writer over the same directory must restore the rotation cursor, so no file grows past
  /// `maxBytes` (+ one in-flight line) across restarts. Pre-fix, every relaunch restarted at
  /// `coach-0.log` with a zero size counter, letting that file grow by ~`maxBytes` per run.
  @Test func test_relaunch_sizeCapHoldsAcrossRestarts() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let maxBytes = 64
    let line = String(repeating: "x", count: 40)
    let lineBytes = line.utf8.count + 1 // trailing newline

    // Three "launches": each a fresh LogFileWriter instance over the same directory, each writing
    // enough to force rotation. `flush()` before dropping the writer = a clean shutdown boundary.
    for _ in 0..<3 {
      let writer = LogFileWriter(directory: dir, maxBytes: maxBytes, maxFiles: 100)
      for _ in 0..<4 { writer.enqueue(line) }
      await writer.flush()
    }

    // Rotation triggers *after* the write that crosses the cap, so the tight bound per file is
    // `maxBytes + lineBytes - 1`. Anything above that means stale on-disk bytes went uncounted.
    let logFiles = try FileManager.default
      .contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])
      .filter { $0.pathExtension == "log" }
    let sizes = try logFiles.map { try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 }
    #expect(sizes.count > 1, "expected rotations across the three launches, got \(sizes.count) file(s)")
    let cap = maxBytes + lineBytes - 1
    #expect(
      sizes.allSatisfy { $0 <= cap },
      "a log file exceeded the size cap across relaunches: sizes \(sizes), cap \(cap)"
    )
  }

  /// Lines written after a restart must sort *after* every pre-restart line in `recentLines`.
  /// Pre-fix, the new instance appended into `coach-0.log`, splicing post-restart lines ahead of the
  /// older rotated files.
  @Test func test_relaunch_readRecentStaysChronological() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    // maxBytes: 1 → every line rotates, so the first launch leaves several rotated files behind.
    let first = LogFileWriter(directory: dir, maxBytes: 1, maxFiles: 100)
    for index in 0..<5 { first.enqueue("line \(index)") }
    await first.flush()

    // "Relaunch": a brand-new writer over the same directory continues with lines 5..<10.
    let second = LogFileWriter(directory: dir, maxBytes: 1, maxFiles: 100)
    for index in 5..<10 { second.enqueue("line \(index)") }
    await second.flush()

    let numbers = await second.recentLines().compactMap { Int($0.split(separator: " ").last ?? "") }
    #expect(
      numbers == Array(0..<10),
      "post-restart lines must come after every pre-restart line, got: \(numbers)"
    )
  }

  /// Edge: when the newest on-disk file is already at/over `maxBytes`, the restored writer must
  /// advance to a fresh index — the full file may never grow further.
  @Test func test_relaunch_fullNewestFileNeverGrows() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let fullContents = String(repeating: "y", count: 64) + "\n"
    let fullURL = dir.appendingPathComponent("coach-3.log")
    try Data(fullContents.utf8).write(to: fullURL)

    let writer = LogFileWriter(directory: dir, maxBytes: 64, maxFiles: 100)
    #expect(
      await writer.currentFileURL.lastPathComponent == "coach-4.log",
      "a full newest file must push the restored writer to a fresh index"
    )
    writer.enqueue("after restart")
    await writer.flush()

    #expect(contents(of: fullURL) == fullContents, "the at-cap file must stay frozen after relaunch")
    #expect(contents(of: dir.appendingPathComponent("coach-4.log")).contains("after restart"))
  }
}
