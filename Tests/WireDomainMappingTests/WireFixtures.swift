import Foundation
import WireModels

/// Inline `WireModels` fixtures for the mapping tests (no `SampleData` yet — that arrives in
/// Phase 2.3, D17). Parameterised just enough for the acceptance-criteria variants.
enum WireFixtures {
  static func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
  }

  static let generatedAt = Date(timeIntervalSince1970: 1_780_000_000)

  static func session(
    card: WireEnum<WorkoutCard> = .known(.easyRun),
    intensity: WireEnum<WireModels.Intensity> = .known(.easy),
    flags: [String] = ["impact", "totally_new_flag"]
  ) -> WireModels.SessionBlock {
    WireModels.SessionBlock(
      card: card,
      intensity: intensity,
      durationMinLow: 40,
      durationMinHigh: 55,
      flags: flags,
      zoneTarget: .known(.z2),
      hrCapBpm: 150,
      cadenceSpm: 180
    )
  }

  static func dailyBrief(
    sessionCard: WireEnum<WorkoutCard> = .known(.easyRun),
    alternatives: [WireModels.SessionBlock] = [session(card: .known(.activeRecovery))],
    intakeYesterday: WireModels.IntakeSummary? = intake(),
    band: WireEnum<WireModels.ReadinessBand> = .known(.green)
  ) -> WireModels.DailyBrief {
    WireModels.DailyBrief(
      data: WireModels.DailyBriefData(
        date: WireCalendarDate(day(2026, 6, 6)),
        readiness: WireModels.Readiness(
          score: 82,
          band: band,
          penalties: [WireModels.ReadinessPenalty(factor: "hrv_below_baseline", points: 8)]
        ),
        safetyGate: WireModels.SafetyGate(
          triggered: false, reasons: ["gi_flare", "brand_new_reason"], overrideTo: nil
        ),
        session: session(card: sessionCard),
        alternatives: alternatives,
        skipOk: true,
        macroFocus: macroFocus(),
        intakeYesterday: intakeYesterday,
        generatedAt: generatedAt,
        cached: false,
        constitutionVersion: "v3"
      ),
      narrative: [
        WireModels.NarrativeSection(type: .known(.summary), heading: "Go", body: "Green."),
      ]
    )
  }

  static func intake() -> WireModels.IntakeSummary {
    WireModels.IntakeSummary(
      date: WireCalendarDate(day(2026, 6, 5)),
      caloriesKcal: 2400,
      proteinG: 165,
      vsTarget: WireModels.IntakeVsTarget(caloriesPct: 0.92, proteinHit: true)
    )
  }

  static func macroFocus(dayType: WireEnum<WireModels.DayType> = .known(.moderate)) -> WireModels.MacroFocus {
    WireModels.MacroFocus(
      dayType: dayType,
      caloriesKcal: 2600,
      proteinG: 170,
      carbsG: 300,
      fatGLow: 60,
      fatGHigh: 80,
      hydrationLLow: 2.5,
      hydrationLHigh: 3.5
    )
  }

  static func weeklyPlan(
    restDay: WireModels.RestDayNutrition? = WireModels.RestDayNutrition(caloriesKcal: 2200, carbsG: 220),
    lastWeek: WireModels.LastWeekNutrition? = WireModels.LastWeekNutrition(
      avgCaloriesKcal: 2550, avgProteinG: 168, proteinHitDays: 5, daysOverTarget: 1, daysUnderTarget: 2
    )
  ) -> WireModels.WeeklyPlan {
    WireModels.WeeklyPlan(
      data: WireModels.WeeklyPlanData(
        isoWeek: "2026-W24",
        weekStart: WireCalendarDate(day(2026, 6, 8)),
        budgets: WireModels.WeeklyBudgets(
          hardDays: 2, strengthSessions: 2, longRunKm: 18.0, deload: false
        ),
        core: [
          WireModels.PlannedSession(
            card: .known(.longRun), tier: .known(.core), intensity: .known(.easy),
            isHardDay: false, flags: ["impact"], suggestedDay: .known(.sun),
            durationMinLow: 80, durationMinHigh: 100
          ),
        ],
        extras: [],
        targets: WireModels.WeeklyTargets(
          totalRunKm: 45.0, easyRunRatio: 0.8, strengthSessions: 2, hardDays: 2, cadenceSpm: 178
        ),
        nutrition: WireModels.WeeklyNutrition(
          proteinG: 170, fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5,
          avgCaloriesKcal: 2600,
          dayTypePattern: [
            WireModels.DayTypePatternEntry(
              suggestedDay: "mon", dayType: .known(.moderate), caloriesKcal: 2600, carbsG: 300
            ),
          ],
          restDay: restDay,
          lastWeek: lastWeek
        ),
        constantsRecomputed: false,
        generatedAt: generatedAt,
        cached: false
      ),
      narrative: [
        WireModels.NarrativeSection(type: .known(.plan), heading: "Week 24", body: "Build."),
      ]
    )
  }

  static func profile(
    constantsRecomputedWeek: String? = "2026-W22"
  ) -> WireModels.ProfileResponse {
    WireModels.ProfileResponse(
      athlete: WireModels.AthleteOut(age: 34, sex: "male", heightCm: 182, goalWeightKg: 75.0),
      zones: WireModels.ZonesOut(
        z1: WireModels.ZoneRange(low: 100, high: 130),
        z2: WireModels.ZoneRange(low: 131, high: 145),
        z3: WireModels.ZoneRange(low: 146, high: 160),
        z4: WireModels.ZoneRange(low: 161, high: 175),
        z5: WireModels.ZoneRange(low: 176, high: 190)
      ),
      thresholds: WireModels.ThresholdsOut(
        maxHr: 190, rhrBaseline: 48, hrvBaselineMs: 65, easyHrCap: 150,
        cadenceCurrentSpm: 172, cadenceTargetSpm: 180
      ),
      meta: WireModels.MetaOut(
        constitutionVersion: "v3", constantsRecomputedWeek: constantsRecomputedWeek
      )
    )
  }
}
