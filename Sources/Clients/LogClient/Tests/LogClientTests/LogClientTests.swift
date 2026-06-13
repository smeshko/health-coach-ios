import Dependencies
import Foundation
import Testing

@testable import LogClient

struct LogClientTests {
  // MARK: - LogTimestamp

  @Test func test_logTimestamp_roundTrips_acrossSpringForwardBoundary() throws {
    // Europe/Sofia springs forward on 2026-03-29 at 03:00 → 04:00 (EET→EEST). Instants on either side
    // of the gap are unambiguous, so format → parse must recover the exact instant.
    let sofia = TimeZone.europeSofia
    var before = DateComponents()
    before.timeZone = sofia
    before.year = 2026; before.month = 3; before.day = 29
    before.hour = 2; before.minute = 30; before.second = 15; before.nanosecond = 123_000_000
    let beforeDate = try #require(Calendar.europeSofia.date(from: before))

    let beforeString = LogTimestamp.format(beforeDate)
    #expect(beforeString == "2026-03-29 02:30:15.123", "got: \(beforeString)")
    let beforeParsed = try #require(LogTimestamp.parse(beforeString))
    #expect(beforeParsed == beforeDate, "spring-forward pre-gap instant must round-trip")

    // The first instant after the gap (wall-clock jumps straight to 04:00) is likewise unambiguous.
    var after = DateComponents()
    after.timeZone = sofia
    after.year = 2026; after.month = 3; after.day = 29
    after.hour = 4; after.minute = 0; after.second = 0
    let afterDate = try #require(Calendar.europeSofia.date(from: after))
    let afterString = LogTimestamp.format(afterDate)
    #expect(afterString == "2026-03-29 04:00:00.000", "got: \(afterString)")
    #expect(LogTimestamp.parse(afterString) == afterDate, "spring-forward post-gap instant must round-trip")
  }

  @Test func test_logTimestamp_ambiguousFallBackHour_isStringStable() {
    // The fall-back repeated hour (2026-10-25, EEST→EET) can't uniquely round-trip a wall-clock string
    // without a UTC offset; the contract is only that format is a stable function of the string — same
    // string in, same Date out, idempotently.
    let stamp = "2026-10-25 03:30:00.000"
    let first = LogTimestamp.parse(stamp)
    let second = LogTimestamp.parse(stamp)
    #expect(first == second, "parse must be deterministic for a fixed string")
    if let first {
      #expect(LogTimestamp.format(first) == stamp, "format∘parse must reproduce the wall-clock string")
    } else {
      Issue.record("ambiguous-hour timestamp failed to parse: \(stamp)")
    }
  }

  @Test func test_logTimestamp_returnsNilForMalformed() {
    #expect(LogTimestamp.parse("not a timestamp") == nil)
    #expect(LogTimestamp.parse("2026-03-29") == nil)
    #expect(LogTimestamp.parse("") == nil)
  }

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
