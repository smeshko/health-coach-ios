import DomainModels
import Foundation
import WireModels

/// Typed `WireModels` DTO builders for the mapping tests.
///
/// Phase 11.6 (TASK-003) audited these against SampleData: they are kept as **divergent-by-design**
/// survivors, NOT re-pointed. Every builder deliberately carries off-canon values the SampleData
/// resources do not — unknown flags (`"totally_new_flag"`), unknown reasons (`"brand_new_reason"`),
/// a `.longRun` core card, nil rest-day/last-week variants — precisely to exercise the mapping's
/// tolerant unknown-string handling (the point of these tests). No builder exactly mirrors a
/// SampleData scenario, so re-pointing via `jsonData` would lose the divergence; re-pointing via
/// `.domain` is forbidden (it would run the very mapping under test). They stay inline.
enum WireFixtures {
  static func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
  }

  static let generatedAt = Date(timeIntervalSince1970: 1_780_000_000)

  static func session(
    card: Card = .easyRun,
    intensity: Intensity = .easy,
    flags: [String] = ["impact", "totally_new_flag"]
  ) -> WireModels.SessionBlock {
    WireModels.SessionBlock(
      card: card,
      intensity: intensity,
      durationMinLow: 40,
      durationMinHigh: 55,
      flags: flags,
      zoneTarget: .z2,
      hrCapBpm: 150,
      cadenceSpm: 180
    )
  }

  static func dailyBrief(
    sessionCard: Card = .easyRun,
    alternatives: [WireModels.SessionBlock] = [session(card: .activeRecovery)],
    intakeYesterday: WireModels.IntakeSummary? = intake(),
    band: ReadinessBand = .green
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
        WireModels.NarrativeSection(type: .summary, heading: "Go", body: "Green."),
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

  static func macroFocus(dayType: DayType = .moderate) -> WireModels.MacroFocus {
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
            card: .longRun, tier: .core, intensity: .easy,
            isHardDay: false, flags: ["impact"], suggestedDay: .sun,
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
              suggestedDay: "mon", dayType: .moderate, caloriesKcal: 2600, carbsG: 300
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
        WireModels.NarrativeSection(type: .plan, heading: "Week 24", body: "Build."),
      ]
    )
  }
}
