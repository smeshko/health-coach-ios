import Foundation
@testable import WireModels
import XCTest

final class ResponseDTOTests: XCTestCase {
  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  func test_dailyBrief_decodes() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBrief)
    XCTAssertEqual(brief.data.readiness.band, .known(.green))
    XCTAssertEqual(brief.data.session.card, .known(.easyRun))
    XCTAssertFalse(brief.narrative.isEmpty)
  }

  func test_weeklyPlan_decodes() throws {
    let plan = try decode(WeeklyPlan.self, from: Fixtures.weeklyPlan)
    XCTAssertEqual(plan.data.isoWeek, "2026-W24")
    XCTAssertEqual(plan.data.core.first?.card, .known(.longRun))
  }

  func test_profileResponse_decodes() throws {
    let profile = try decode(ProfileResponse.self, from: Fixtures.profileResponse)
    XCTAssertEqual(profile.zones.z1.low, 100)
    XCTAssertEqual(profile.thresholds.maxHr, 190)
    XCTAssertEqual(profile.meta.constitutionVersion, "v3")
  }

  func test_syncResponse_decodes() throws {
    let response = try decode(SyncResponse.self, from: Fixtures.syncResponse)
    XCTAssertEqual(response.recordsUpserted, 12)
    XCTAssertTrue(response.checkinSaved)
  }

  func test_healthResponse_decodes() throws {
    let response = try decode(HealthResponse.self, from: Fixtures.healthResponse)
    XCTAssertEqual(response.status, "ok")
  }

  func test_errorResponse_decodes() throws {
    let envelope = try decode(ErrorResponse.self, from: Fixtures.errorResponse)
    XCTAssertEqual(envelope.error.code, .known(.validationError))
    XCTAssertEqual(envelope.error.detail, "date must be yyyy-MM-dd")
  }

  func test_intakeSummary_vsTargetRequiredWithNullMacros() throws {
    let json = """
    {
      "date": "2026-06-06",
      "caloriesKcal": null,
      "proteinG": null,
      "vsTarget": { "caloriesPct": 0.0, "proteinHit": false }
    }
    """
    let intake = try decode(IntakeSummary.self, from: json)
    XCTAssertNil(intake.caloriesKcal)
    XCTAssertNil(intake.proteinG)
    XCTAssertEqual(intake.vsTarget.caloriesPct, 0.0)
  }

  func test_weeklyTargets_totalRunKmNull() throws {
    let json = """
    {
      "totalRunKm": null,
      "easyRunRatio": 0.8,
      "strengthSessions": 2,
      "hardDays": 2,
      "cadenceSpm": 178
    }
    """
    let targets = try decode(WeeklyTargets.self, from: json)
    XCTAssertNil(targets.totalRunKm)
    XCTAssertEqual(targets.cadenceSpm, 178)
  }
}
