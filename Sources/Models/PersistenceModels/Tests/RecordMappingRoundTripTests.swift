import DomainModels
import Foundation
@testable import PersistenceModels
import SampleData
import XCTest

/// `Domain → Record → Domain` round-trips, asserting full `Equatable` equality. Composite records
/// are driven by `SampleData` domain values; the flat columnar records (which have no `SampleData`
/// fixture) are driven by literal domain values.
final class RecordMappingRoundTripTests: XCTestCase {
  private let day = Date(timeIntervalSince1970: 1_780_000_000)

  // MARK: - Composite records (serialized body)

  func test_dailyBrief_roundTrips() throws {
    let scenarios: [SampleScenario] = [
      .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed,
      .dailyBriefRestGIFlare, .dailyBriefRestIllness, .dailyBriefRestKnee, .dailyBriefNoFood,
    ]
    for scenario in scenarios {
      let domain = try SampleData.dailyBrief(scenario).domain
      let roundTripped = try DailyBriefRecord(domain: domain).toDomain()
      XCTAssertEqual(roundTripped, domain, "\(scenario)")
    }
  }

  func test_unknownFlag_survivesRoundTrip() throws {
    let domain = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    let roundTripped = try DailyBriefRecord(domain: domain).toDomain()
    XCTAssertTrue(roundTripped.session.flags.contains(.unknown("moon_phase")))
  }

  func test_nilIntake_survivesRoundTrip() throws {
    let domain = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    XCTAssertNil(domain.intakeYesterday)
    let roundTripped = try DailyBriefRecord(domain: domain).toDomain()
    XCTAssertNil(roundTripped.intakeYesterday)
  }

  func test_weeklyPlan_roundTrips() throws {
    let domain = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    let roundTripped = try WeeklyPlanRecord(domain: domain).toDomain()
    XCTAssertEqual(roundTripped, domain)
    XCTAssertTrue(roundTripped.budgets.deload)
    XCTAssertNil(roundTripped.budgets.longRunKm)
  }

  func test_profile_roundTrips() throws {
    let domain = try SampleData.profile().domain
    let roundTripped = try ProfileRecord(domain: domain).toDomain()
    XCTAssertEqual(roundTripped, domain)
  }

  // MARK: - Flat columnar records (literal domain values)

  func test_checkIn_roundTrips() {
    let domain = DomainModels.CheckIn(date: day, giSymptoms: true, kneePain: 4, illness: false)
    XCTAssertEqual(CheckInRecord(domain: domain).toDomain(), domain)
  }

  func test_strengthTest_roundTrips() {
    let domain = DomainModels.StrengthTest(date: day, maxPushups: 42, maxPullups: 14)
    XCTAssertEqual(StrengthTestRecord(domain: domain).toDomain(), domain)
  }

  func test_syncWatermark_roundTrips() {
    let domain = SyncWatermark(anchor: "anchor-token", serverTime: day)
    XCTAssertEqual(SyncWatermarkRecord(domain: domain).toDomain(), domain)
    // The nil-anchor case (first ever sync) also round-trips.
    let firstSync = SyncWatermark(anchor: nil, serverTime: day)
    XCTAssertEqual(SyncWatermarkRecord(domain: firstSync).toDomain(), firstSync)
  }
}
