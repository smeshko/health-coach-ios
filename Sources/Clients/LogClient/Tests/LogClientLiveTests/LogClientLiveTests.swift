import Dependencies
import DevSettings
import Foundation
import LogClient
import Testing

@testable import LogClientLive

// Parallel-safe: every test writes into its own UUID-suffixed temp directory (see
// `tempDirectory`), so no `.serialized` is needed despite the on-disk state.
struct LogClientLiveTests {
  /// A throwaway temp directory cleaned up after each test.
  private func tempDirectory(_ name: String = #function) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LogClientLiveTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    return url
  }

  private func contents(of url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }

  @Test func test_http_alwaysWritesReadableLine() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)

    await withDependencies {
      $0.devSettings = .testValue // every category off
    } operation: {
      let log = LogClient.live(writer: writer, console: { _ in })
      log.error("boom", category: .http, metadata: ["status": "401"])
    }
    await writer.flush()

    let url = await writer.currentFileURL
    let line = contents(of: url)
    #expect(line.contains("[http]"), "category segment missing: \(line)")
    #expect(line.contains("ERROR"), "level missing: \(line)")
    #expect(line.contains("boom"), "message missing: \(line)")
    #expect(line.contains("status=401"), "metadata missing: \(line)")
  }

  @Test func test_gatedCategory_droppedWhenOff_emittedWhenOn() async throws {
    // OFF: testValue resolves every category to off → the .tca line is dropped.
    let offDir = tempDirectory("off")
    defer { try? FileManager.default.removeItem(at: offDir) }
    let offWriter = LogFileWriter(directory: offDir)
    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      let log = LogClient.live(writer: offWriter, console: { _ in })
      log.info("hidden", category: .tca)
    }
    await offWriter.flush()
    let offURL = await offWriter.currentFileURL
    #expect(!contents(of: offURL).contains("hidden"))

    // ON: flip the .tca toggle on → the line is emitted.
    let onDir = tempDirectory("on")
    defer { try? FileManager.default.removeItem(at: onDir) }
    let onWriter = LogFileWriter(directory: onDir)
    await withDependencies {
      $0.devSettings = .testValue
      $0.devSettings.isLogCategoryEnabled = { $0 == LogCategory.tca.rawValue }
    } operation: {
      let log = LogClient.live(writer: onWriter, console: { _ in })
      log.info("shown", category: .tca)
    }
    await onWriter.flush()
    let onURL = await onWriter.currentFileURL
    #expect(contents(of: onURL).contains("shown"))
  }

  @Test func test_readRecent_returnsWrittenLinesInOrder() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)
    let log = LogClient.live(writer: writer, console: { _ in })

    // `.http` is always-on, so both lines persist regardless of the (off) DevSettings toggles.
    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      log.error("first", category: .http)
      log.error("second", category: .http)
    }
    await writer.flush()

    let lines = await log.readRecent()
    #expect(lines.count == 2, "both written lines should be read back")
    #expect(lines.first?.contains("first") == true, "chronological order: oldest first")
    #expect(lines.last?.contains("second") == true)
  }

  @Test func test_readRecent_emptyWhenNothingLogged() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let log = LogClient.live(writer: LogFileWriter(directory: dir), console: { _ in })
    #expect(await log.readRecent().isEmpty)
  }

  @Test func test_clear_removesAllPersistedLines() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)
    let log = LogClient.live(writer: writer, console: { _ in })

    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      log.error("first", category: .http)
      log.error("second", category: .http)
    }
    await writer.flush()
    #expect(!(await log.readRecent().isEmpty), "precondition: lines were written")

    // `clear()` is FIFO-ordered after the writes, so it removes them; the next read is empty.
    await log.clear()
    #expect(await log.readRecent().isEmpty, "clear must delete every persisted log line")
  }

  @Test func test_writtenLine_isByteIdenticalFullLine() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)

    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      // Two metadata keys out of sorted order on input → the renderer must emit them sorted by key.
      LogClient.live(writer: writer, console: { _ in })
        .error("boom", category: .http, metadata: ["status": "401", "path": "/x"])
    }
    await writer.flush()

    // Full end-to-end pin of the rendered line. Only the timestamp varies (current `Date()`), so it is
    // matched by shape; everything after it — level token, `[category]`, message, and the sorted
    // ` — key=value …` metadata tail — is asserted exactly (byte-identical to the pre-11.5 handler).
    let line = contents(of: await writer.currentFileURL).trimmingCharacters(in: .newlines)
    let expected =
      #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} ERROR \[http\] boom — path=/x status=401$"#
    #expect(
      line.range(of: expected, options: .regularExpression) != nil,
      "rendered line drifted from the pinned shape, got: \(line)"
    )
  }

  /// The rendered-line body after the `yyyy-MM-dd HH:mm:ss.SSS ` timestamp prefix (two space-delimited
  /// tokens: date + time). The timestamp itself is the only non-deterministic part, so it is dropped.
  private func bodyAfterTimestamp(_ line: String) -> String {
    line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false).dropFirst(2)
      .joined(separator: " ")
  }

  @Test func test_render_pinsExactTokensAndSortedMetadata() {
    // `render` is the deterministic core; pin the level token map and the sorted-metadata tail directly
    // (the timestamp prefix is the only non-deterministic part and is split off here).
    let line = LogClient.render(
      level: .notice, category: .tca, message: "hello",
      metadata: ["b": "2", "a": "1", "c": "3"]
    )
    let body = bodyAfterTimestamp(line)
    #expect(body == "NOTICE [tca] hello — a=1 b=2 c=3", "got: \(body)")

    // No metadata → no ` — …` tail.
    let bare = LogClient.render(level: .debug, category: .app, message: "m", metadata: [:])
    let bareBody = bodyAfterTimestamp(bare)
    #expect(bareBody == "DEBUG [app] m", "got: \(bareBody)")
  }

  @Test func test_levelTokens_matchLegacyMap() {
    let tokens = [LogLevel.debug, .info, .notice, .error].map { level in
      String(
        bodyAfterTimestamp(LogClient.render(level: level, category: .http, message: "x", metadata: [:]))
          .prefix(while: { $0 != " " })
      )
    }
    #expect(tokens == ["DEBUG", "INFO", "NOTICE", "ERROR"])
  }

  @Test func test_rotation_readRecentStaysChronological_pastIndexTen() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    // A tiny cap so each line rotates, and a high file cap so ≥11 files survive — the index crosses 10,
    // where a lexicographic sort would order `coach-10.log` before `coach-2.log`. `readRecent` must keep
    // numeric order (oldest→newest), so the line numbers come back ascending.
    let writer = LogFileWriter(directory: dir, maxBytes: 1, maxFiles: 100)

    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      let log = LogClient.live(writer: writer, console: { _ in })
      for index in 0..<15 {
        log.error("line \(index)", category: .http)
      }
    }
    await writer.flush()

    let lines = await writer.recentLines()
    #expect(lines.count == 15, "expected one line per file across ≥11 rotations, got \(lines.count)")
    // Extract the trailing integer from each "… line N" line and assert strictly ascending.
    let numbers = lines.compactMap { Int($0.split(separator: " ").last ?? "") }
    #expect(numbers == Array(0..<15), "readRecent is not chronological past index 10: \(numbers)")
  }

  /// Pins the serial-actor guarantee the writer's design hangs on (doc: "lines never interleave"): N
  /// writers each enqueuing M uniquely-identifiable lines concurrently must yield whole, non-spliced
  /// lines and the full N×M multiset after a drain. `enqueue` funnels through one `AsyncStream` consumed
  /// by a single actor loop, so a write is never interleaved with another's bytes. Deterministic: the
  /// task group completes all enqueues, then `flush()` (a FIFO sentinel) guarantees every prior write
  /// landed before `recentLines()` reads — no wall-clock waits.
  @Test func test_concurrentEnqueue_yieldsWholeLines_noInterleave() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)

    let writerCount = 8
    let perWriter = 50
    let expected = Set((0..<writerCount).flatMap { writerIndex in
      (0..<perWriter).map { lineIndex in "w\(writerIndex)-l\(lineIndex)" }
    })

    await withTaskGroup(of: Void.self) { group in
      for writerIndex in 0..<writerCount {
        group.addTask {
          for lineIndex in 0..<perWriter {
            writer.enqueue("w\(writerIndex)-l\(lineIndex)")
            await Task.yield() // interleave the producers to actually stress the single consumer
          }
        }
      }
    }
    await writer.flush()

    let lines = await writer.recentLines()
    let shape = #"^w\d+-l\d+$"#
    let spliced = lines.first { $0.range(of: shape, options: .regularExpression) == nil }
    #expect(spliced == nil, "a line was spliced/interleaved: \(spliced ?? "")")
    #expect(lines.count == writerCount * perWriter, "expected \(writerCount * perWriter) lines, got \(lines.count)")
    #expect(Set(lines) == expected, "the read-back set must equal the enqueued set (no loss/dup)")

    // Per-writer order survives: each task enqueues its lines sequentially, so the FIFO stream keeps that
    // writer's lines ascending even though writers interleave with one another.
    for writerIndex in 0..<writerCount {
      let prefix = "w\(writerIndex)-l"
      let mine = lines.filter { $0.hasPrefix(prefix) }.compactMap { Int($0.dropFirst(prefix.count)) }
      #expect(mine == Array(0..<perWriter), "writer \(writerIndex) lines lost their order: \(mine)")
    }
  }

  @Test func test_rotation_capsFileCount() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    // Small cap so a few lines force several rotations; keep at most 3 files.
    let writer = LogFileWriter(directory: dir, maxBytes: 64, maxFiles: 3)

    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      let log = LogClient.live(writer: writer, console: { _ in })
      for index in 0..<40 {
        log.error("line number \(index) padded to force rotation", category: .http)
      }
    }
    await writer.flush()

    let logFiles = try FileManager.default
      .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "log" }
    #expect(logFiles.count <= 3, "rotation must cap the file count, found \(logFiles.count)")
    #expect(logFiles.count > 1, "expected several rotations from 40 lines at a 64-byte cap")
  }
}
