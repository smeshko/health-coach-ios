import Dependencies
import Testing

@testable import LogClient

struct LogClientTests {
  @Test func test_logCategory_isAlwaysOn_onlyForHTTP() {
    #expect(LogCategory.http.isAlwaysOn)
    for category in LogCategory.allCases where category != .http {
      #expect(!category.isAlwaysOn, "\(category) should be gated, not always-on")
    }
  }

  @Test func test_recorder_capturesEmittedEntries() {
    let recorder = LogRecorder()
    withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      @Dependency(\.log) var log
      log.error("boom", category: .http, metadata: ["status": "401"])
    }

    #expect(
      recorder.entries ==
        [.init(level: .error, category: .http, message: "boom", metadata: ["status": "401"])]
    )
  }

  @Test func test_levelHelpers_routeToCorrectLevel() {
    let recorder = LogRecorder()
    let client = LogClient.recording(into: recorder)

    client.error("e", category: .http)
    client.notice("n", category: .tca)
    client.info("i", category: .lifecycle)
    client.debug("d", category: .app)

    #expect(recorder.entries.map(\.level) == [.error, .notice, .info, .debug])
    #expect(recorder.entries.map(\.category) == [.http, .tca, .lifecycle, .app])
    #expect(recorder.entries.map(\.message) == ["e", "n", "i", "d"])
    // Helpers default metadata to empty.
    #expect(recorder.entries.map(\.metadata) == [[:], [:], [:], [:]])
  }
}
