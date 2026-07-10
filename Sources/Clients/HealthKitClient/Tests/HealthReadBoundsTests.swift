import Foundation
import Testing

@testable import HealthKitClient

/// Pins the `HealthReadBounds` contract: the `since(_:)` factory carries the app-wide default
/// bounds (per-type row limit + whole-read timeout), the memberwise init allows explicit call
/// sites, and `testValue.deltaSamples` honours `bounds.since` (the pre-existing anchor filter).
struct HealthReadBoundsTests {
  @Test func test_sinceFactory_appliesTheDocumentedDefaults() {
    let date = Date(timeIntervalSinceReferenceDate: 123_456)
    let bounds = HealthReadBounds.since(date)
    #expect(bounds.since == date)
    #expect(bounds.limitPerType == 10000, "the app-wide default per-type row limit")
    #expect(bounds.timeout == .seconds(15), "the app-wide default whole-read timeout")
  }

  /// Review #2.3: the interface claims an unbounded read is not expressible — HealthKit's
  /// no-limit sentinel (`HKObjectQueryNoLimit` == 0) and negative limits must be unrepresentable,
  /// clamped to the minimum bounded read rather than reaching `HKSampleQuery.limit`.
  @Test func test_init_clampsNonPositiveLimits_noLimitSentinelUnrepresentable() {
    let date = Date(timeIntervalSinceReferenceDate: 7)
    let sentinel = HealthReadBounds(since: date, limitPerType: 0, timeout: .seconds(1))
    #expect(sentinel.limitPerType == 1, "HKObjectQueryNoLimit (0) must clamp to a bounded read")
    let negative = HealthReadBounds(since: date, limitPerType: -5, timeout: .seconds(1))
    #expect(negative.limitPerType == 1, "negative limits must clamp to a bounded read")
    let valid = HealthReadBounds(since: date, limitPerType: 1, timeout: .seconds(1))
    #expect(valid.limitPerType == 1, "the minimum valid limit passes through unchanged")
  }

  /// Review #2.2 + #3.1: `HKActivitySummaryQuery` has no `limit` parameter, so the activity
  /// read's bound is its WINDOW — and the activity predicate is inclusive at BOTH day
  /// endpoints, so `activitySince` floors the start at `limitPerType - 1` days before now
  /// (floor day + today inclusive = exactly `limitPerType` distinct days ⇒ at most
  /// `limitPerType` rows). A `.distantPast` probe is clamped; a recent delta anchor passes
  /// through untouched.
  @Test func test_activitySince_floorsDistantPast_keepsRecentAnchors() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
    let now = Date(timeIntervalSince1970: 1_780_898_400) // 2026-06-08 ~09:00 Europe/Sofia

    let probe = HealthReadBounds(since: .distantPast, limitPerType: 10, timeout: .seconds(1))
    let floored = probe.activitySince(now: now, calendar: calendar)
    let expectedFloor = try #require(calendar.date(byAdding: .day, value: -9, to: now))
    #expect(
      floored == expectedFloor,
      "a distant-past probe is clamped to limitPerType days INCLUSIVE of today (review #3.1)"
    )

    let recentAnchor = try #require(calendar.date(byAdding: .day, value: -2, to: now))
    let delta = HealthReadBounds(since: recentAnchor, limitPerType: 10, timeout: .seconds(1))
    #expect(
      delta.activitySince(now: now, calendar: calendar) == recentAnchor,
      "a delta anchor inside the window is unchanged"
    )
  }

  /// Review #3.1 regression pin at the boundary: with `limitPerType == 1` the window must span
  /// exactly ONE day — the floor is `now` itself (`-(1 - 1) = 0` days), not yesterday (which
  /// would make the both-endpoints-inclusive predicate span two summary rows).
  @Test func test_activitySince_limitOne_spansExactlyToday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
    let now = Date(timeIntervalSince1970: 1_780_898_400) // 2026-06-08 ~09:00 Europe/Sofia

    let bounds = HealthReadBounds(since: .distantPast, limitPerType: 1, timeout: .seconds(1))
    #expect(
      bounds.activitySince(now: now, calendar: calendar) == now,
      "limit 1 ⇒ the floor is now's own day; -1 day would span two inclusive endpoints"
    )
  }

  @Test func test_memberwiseInit_carriesExplicitValues() {
    let date = Date(timeIntervalSinceReferenceDate: 42)
    let bounds = HealthReadBounds(since: date, limitPerType: 500, timeout: .seconds(3))
    #expect(bounds.since == date)
    #expect(bounds.limitPerType == 500)
    #expect(bounds.timeout == .seconds(3))
    #expect(bounds != .since(date), "explicit bounds differ from the defaults (Equatable)")
  }

  @Test func test_testValue_deltaSamples_filtersCannedSamplesAfterBoundsSince() async throws {
    // The canned set places one record strictly before the anchor fixture; `deltaSamples` must
    // apply the same inclusive `filtered(after:)` boundary as before the signature change.
    let anchor = CannedHealthSamples.healthAnchorFixture
    let set = try await HealthKitClient.testValue.deltaSamples(.since(anchor))
    #expect(set.records.count == 2, "the before-anchor record is excluded")
    #expect(!set.records.contains { $0.type == .stepCount })
    #expect(set.workouts.count == 1)
    #expect(set.activity.count == 1)

    // A since-floor after every canned sample → everything excluded.
    let far = Date(timeIntervalSinceReferenceDate: 1_000_000_000)
    let empty = try await HealthKitClient.testValue.deltaSamples(.since(far))
    #expect(empty.records.isEmpty)
    #expect(empty.workouts.isEmpty)
    #expect(empty.activity.isEmpty)
  }
}
