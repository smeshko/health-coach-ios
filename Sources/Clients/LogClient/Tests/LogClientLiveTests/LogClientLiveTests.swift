import Dependencies
import DevSettings
import Foundation
import LogClient
import XCTest

@testable import LogClientLive

final class LogClientLiveTests: XCTestCase {
  /// A throwaway temp directory cleaned up after each test.
  private func tempDirectory(_ name: String = #function) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LogClientLiveTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    return url
  }

  private func contents(of url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }

  func test_http_alwaysWritesReadableLine() async throws {
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
    XCTAssertTrue(line.contains("[http]"), "category segment missing: \(line)")
    XCTAssertTrue(line.contains("ERROR"), "level missing: \(line)")
    XCTAssertTrue(line.contains("boom"), "message missing: \(line)")
    XCTAssertTrue(line.contains("status=401"), "metadata missing: \(line)")
  }

  func test_gatedCategory_droppedWhenOff_emittedWhenOn() async throws {
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
    XCTAssertFalse(contents(of: offURL).contains("hidden"))

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
    XCTAssertTrue(contents(of: onURL).contains("shown"))
  }

  func test_rotation_capsFileCount() async throws {
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
    XCTAssertLessThanOrEqual(logFiles.count, 3, "rotation must cap the file count, found \(logFiles.count)")
    XCTAssertGreaterThan(logFiles.count, 1, "expected several rotations from 40 lines at a 64-byte cap")
  }
}
