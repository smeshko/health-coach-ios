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

  @Test func test_writtenLine_carriesLocalDateAndCategory() async throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogFileWriter(directory: dir)

    await withDependencies {
      $0.devSettings = .testValue
    } operation: {
      LogClient.live(writer: writer, console: { _ in }).error("boom", category: .http)
    }
    await writer.flush()

    let line = contents(of: await writer.currentFileURL)
    // The line now begins with a full `yyyy-MM-dd HH:mm:ss.SSS` local timestamp (was time-only UTC).
    let datedPrefix = #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} ERROR \[http\] boom"#
    #expect(
      line.range(of: datedPrefix, options: .regularExpression) != nil,
      "expected a dated, parseable line, got: \(line)"
    )
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
