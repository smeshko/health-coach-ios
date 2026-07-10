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
