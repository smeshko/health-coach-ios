import Dependencies
import Foundation
import WireModels

extension APIClient: TestDependencyKey {
  /// Canned `WireModels` DTOs, no network. `sessionEvents` is an immediately-finished stream.
  public static var testValue: APIClient {
    APIClient(
      health: { CannedResponses.health },
      probe: { true },
      sync: { _ in CannedResponses.syncResponse },
      dailyBrief: { _, _ in CannedResponses.dailyBrief },
      weeklyBrief: { _, _ in CannedResponses.weeklyPlan },
      profile: { CannedResponses.profile },
      sessionEvents: { AsyncStream { $0.finish() } }
    )
  }

  public static var previewValue: APIClient { testValue }
}

/// Inline minimal fixtures for the interface's `testValue`/`previewValue` (SampleData arrives later
/// and can be re-pointed). Built via the `WireModels` public initializers.
enum CannedResponses {
  static let day = Date(timeIntervalSince1970: 1_780_000_000)
  static let calendarDay = WireCalendarDate(day)

  static let health = HealthResponse(status: "ok", serverTime: day)

  static let syncResponse = SyncResponse(
    recordsUpserted: 0,
    recordsDuplicate: 0,
    workoutsUpserted: 0,
    activityDaysUpserted: 0,
    checkinSaved: false,
    strengthTestSaved: false,
    serverTime: day
  )

  static let dailyBrief = DailyBrief(
    data: DailyBriefData(
      date: calendarDay,
      readiness: Readiness(score: 80, band: .known(.green), penalties: []),
      safetyGate: SafetyGate(triggered: false, reasons: []),
      session: SessionBlock(
        card: .known(.easyRun), intensity: .known(.easy),
        durationMinLow: 40, durationMinHigh: 55, flags: []
      ),
      alternatives: [],
      skipOk: true,
      macroFocus: MacroFocus(
        dayType: .known(.moderate), caloriesKcal: 2600, proteinG: 170, carbsG: 300,
        fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5
      ),
      generatedAt: day,
      cached: false
    ),
    narrative: []
  )

  static let weeklyPlan = WeeklyPlan(
    data: WeeklyPlanData(
      isoWeek: "2026-W24",
      weekStart: calendarDay,
      budgets: WeeklyBudgets(hardDays: 2, strengthSessions: 2, deload: false),
      core: [],
      extras: [],
      targets: WeeklyTargets(
        totalRunKm: 40, easyRunRatio: 0.8, strengthSessions: 2, hardDays: 2, cadenceSpm: 178
      ),
      nutrition: WeeklyNutrition(
        proteinG: 170, fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5,
        avgCaloriesKcal: 2600, dayTypePattern: []
      ),
      constantsRecomputed: false,
      generatedAt: day,
      cached: false
    ),
    narrative: []
  )

  static let profile = ProfileResponse(
    athlete: AthleteOut(age: 34, sex: "male", heightCm: 182, goalWeightKg: 75),
    zones: ZonesOut(
      z1: ZoneRange(low: 100, high: 130),
      z2: ZoneRange(low: 131, high: 145),
      z3: ZoneRange(low: 146, high: 160),
      z4: ZoneRange(low: 161, high: 175),
      z5: ZoneRange(low: 176, high: 190)
    ),
    thresholds: ThresholdsOut(
      maxHr: 190, rhrBaseline: 48, hrvBaselineMs: 65, easyHrCap: 150,
      cadenceCurrentSpm: 172, cadenceTargetSpm: 180
    ),
    meta: MetaOut(constitutionVersion: "v3")
  )
}
