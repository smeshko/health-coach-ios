import Foundation
import Testing

@testable import WireModels

// Note: `DomainModels` is intentionally NOT imported — the shared closed-enum cases resolve via the
// DTO field's inferred type, and importing it would collide DTO struct names across the two modules.
struct ResponseDTOTests {
  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  @Test func test_dailyBrief_decodes() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBrief)
    #expect(brief.data.readiness.band == .green)
    #expect(brief.data.session.card == .easyRun)
    #expect(!brief.narrative.isEmpty)
  }

  @Test func test_weeklyPlan_decodes() throws {
    let plan = try decode(WeeklyPlan.self, from: Fixtures.weeklyPlan)
    #expect(plan.data.isoWeek == "2026-W24")
    #expect(plan.data.core.first?.card == .longRun)
  }

  @Test func test_profileResponse_decodes() throws {
    let profile = try decode(ProfileResponse.self, from: Fixtures.profileResponse)
    #expect(profile.zones.z1.low == 100)
    #expect(profile.thresholds.maxHr == 190)
    #expect(profile.meta.constitutionVersion == "v3")
  }

  @Test func test_syncResponse_decodes() throws {
    let response = try decode(SyncResponse.self, from: Fixtures.syncResponse)
    #expect(response.recordsUpserted == 12)
    #expect(response.checkinSaved)
  }

  @Test func test_errorResponse_decodes() throws {
    let envelope = try decode(ErrorResponse.self, from: Fixtures.errorResponse)
    #expect(envelope.error.code == .validationError)
    #expect(envelope.error.detail == "date must be yyyy-MM-dd")
  }

  @Test func test_intakeSummary_vsTargetRequiredWithNullMacros() throws {
    let json = """
    {
      "date": "2026-06-06",
      "caloriesKcal": null,
      "proteinG": null,
      "vsTarget": { "caloriesPct": 0.0, "proteinHit": false }
    }
    """
    let intake = try decode(IntakeSummary.self, from: json)
    #expect(intake.caloriesKcal == nil)
    #expect(intake.proteinG == nil)
    #expect(intake.vsTarget.caloriesPct == 0.0)
  }

  @Test func test_weeklyTargets_totalRunKmNull() throws {
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
    #expect(targets.totalRunKm == nil)
    #expect(targets.cadenceSpm == 178)
  }
}
