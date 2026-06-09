import Dependencies
import XCTest

@testable import LogClient

final class LogClientTests: XCTestCase {
  func test_logCategory_isAlwaysOn_onlyForHTTP() {
    XCTAssertTrue(LogCategory.http.isAlwaysOn)
    for category in LogCategory.allCases where category != .http {
      XCTAssertFalse(category.isAlwaysOn, "\(category) should be gated, not always-on")
    }
  }

  func test_recorder_capturesEmittedEntries() {
    let recorder = LogRecorder()
    withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      @Dependency(\.log) var log
      log.error("boom", category: .http, metadata: ["status": "401"])
    }

    XCTAssertEqual(
      recorder.entries,
      [.init(level: .error, category: .http, message: "boom", metadata: ["status": "401"])]
    )
  }

  func test_levelHelpers_routeToCorrectLevel() {
    let recorder = LogRecorder()
    let client = LogClient.recording(into: recorder)

    client.error("e", category: .http)
    client.notice("n", category: .tca)
    client.info("i", category: .lifecycle)
    client.debug("d", category: .app)

    XCTAssertEqual(recorder.entries.map(\.level), [.error, .notice, .info, .debug])
    XCTAssertEqual(recorder.entries.map(\.category), [.http, .tca, .lifecycle, .app])
    XCTAssertEqual(recorder.entries.map(\.message), ["e", "n", "i", "d"])
    // Helpers default metadata to empty.
    XCTAssertEqual(recorder.entries.map(\.metadata), [[:], [:], [:], [:]])
  }
}
