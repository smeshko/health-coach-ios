import DomainModels
import Foundation
import SampleData
import Testing

@testable import PersistenceModels

/// `Domain → Record → Domain` round-trips, asserting full `Equatable` equality. Composite records
/// are driven by `SampleData` domain values; the flat columnar records (which have no `SampleData`
/// fixture) are driven by literal domain values.
struct RecordMappingRoundTripTests {
  private let day = Date(timeIntervalSince1970: 1_780_000_000)

  // MARK: - Composite records (serialized body)

  @Test func test_dailyBrief_roundTrips() throws {
    let scenarios: [SampleScenario] = [
      .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed,
      .dailyBriefRestGIFlare, .dailyBriefRestIllness, .dailyBriefRestKnee, .dailyBriefNoFood,
    ]
    for scenario in scenarios {
      let domain = try SampleData.dailyBrief(scenario).domain
      let roundTripped = try DailyBriefRecord(domain: domain).toDomain()
      #expect(roundTripped == domain, "\(scenario)")
    }

    // `.dailyBriefNoFood` is the scenario carrying an `.unknown` flag and a nil yesterday-intake;
    // the full-equality round-trip above already proves both survive, but assert the fixture content
    // explicitly so a future fixture edit that drops them can't silently weaken this coverage.
    let noFood = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    #expect(noFood.intakeYesterday == nil)
    let noFoodRoundTripped = try DailyBriefRecord(domain: noFood).toDomain()
    #expect(noFoodRoundTripped.session.flags.contains(.unknown("moon_phase")))
    #expect(noFoodRoundTripped.intakeYesterday == nil)
  }

  @Test func test_weeklyPlan_roundTrips() throws {
    let domain = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    let roundTripped = try WeeklyPlanRecord(domain: domain).toDomain()
    #expect(roundTripped == domain)
    #expect(roundTripped.budgets.deload)
    #expect(roundTripped.budgets.longRunKm == nil)
  }

  @Test func test_profile_roundTrips() throws {
    let domain = try SampleData.profile().domain
    let roundTripped = try ProfileRecord(domain: domain).toDomain()
    #expect(roundTripped == domain)
  }

  /// Corrupt-body tolerance (2026-06-12 audit gap): the v3 migration only guards against
  /// format-version skew, not an in-place corrupt row. A `body` blob that is valid JSON but not a
  /// decodable `DailyBrief` must surface a clean `DecodingError` out of `toDomain()` (which the
  /// repository read path turns into a typed brief error) — never a crash or a wedge.
  @Test func test_corruptBody_throwsDecodingError() {
    let record = DailyBriefRecord(
      date: day, cached: true, generatedAt: day, constitutionVersion: "v3",
      body: Data(#"{"not":"a daily brief"}"#.utf8)
    )
    #expect(throws: DecodingError.self) { _ = try record.toDomain() }
  }

  // MARK: - Flat columnar records (literal domain values)

  @Test func test_checkIn_roundTrips() {
    let domain = DomainModels.CheckIn(date: day, giSymptoms: true, kneePain: 4, illness: false)
    #expect(CheckInRecord(domain: domain).toDomain() == domain)
  }

  @Test func test_strengthTest_roundTrips() {
    let domain = DomainModels.StrengthTest(date: day, maxPushups: 42, maxPullups: 14)
    #expect(StrengthTestRecord(domain: domain).toDomain() == domain)
  }

  @Test func test_syncWatermark_roundTrips() {
    let domain = SyncWatermark(anchor: "anchor-token", serverTime: day)
    #expect(SyncWatermarkRecord(domain: domain).toDomain() == domain)
    // The nil-anchor case (first ever sync) also round-trips.
    let firstSync = SyncWatermark(anchor: nil, serverTime: day)
    #expect(SyncWatermarkRecord(domain: firstSync).toDomain() == firstSync)
  }
}
