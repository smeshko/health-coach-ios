import DomainModels
import Foundation

/// The expected `DomainModels` values that `WireFixtures` map to. Kept beside `WireFixtures` so the
/// full-struct equality assertions enforce mapping **totality** (every field, no silent drop/swap).
enum DomainFixtures {
  static func session(card: Card = .easyRun) -> DomainModels.SessionBlock {
    DomainModels.SessionBlock(
      card: card,
      intensity: .easy,
      zoneTarget: .z2,
      durationMinLow: 40,
      durationMinHigh: 55,
      hrCapBpm: 150,
      flags: [.impact, .unknown("totally_new_flag")]
    )
  }

  static func dailyBrief() -> DomainModels.DailyBrief {
    DomainModels.DailyBrief(
      date: WireFixtures.day(2026, 6, 6),
      readiness: DomainModels.Readiness(
        score: 82,
        band: .green,
        penalties: [DomainModels.ReadinessPenalty(factor: .hrvBelowBaseline, points: 8)]
      ),
      safetyGate: DomainModels.SafetyGate(
        triggered: false, reasons: [.giFlare, .unknown("brand_new_reason")], overrideTo: nil
      ),
      session: session(),
      alternatives: [session(card: .activeRecovery)],
      skipOk: true,
      macroFocus: DomainModels.MacroFocus(
        dayType: .moderate,
        caloriesKcal: 2600,
        proteinG: 170,
        carbsG: 300,
        fatGLow: 60,
        fatGHigh: 80,
        hydrationLLow: 2.5,
        hydrationLHigh: 3.5
      ),
      intakeYesterday: DomainModels.IntakeSummary(
        date: WireFixtures.day(2026, 6, 5),
        caloriesKcal: 2400,
        proteinG: 165,
        vsTarget: DomainModels.IntakeVsTarget(caloriesPct: 0.92, proteinHit: true)
      ),
      generatedAt: WireFixtures.generatedAt,
      cached: false,
      constitutionVersion: "v3",
      narrative: [DomainModels.NarrativeSection(type: .summary, heading: "Go", body: "Green.")]
    )
  }

  static func weeklyPlan() -> DomainModels.WeeklyPlan {
    DomainModels.WeeklyPlan(
      isoWeek: "2026-W24",
      weekStart: WireFixtures.day(2026, 6, 8),
      budgets: DomainModels.WeeklyBudgets(
        hardDays: 2, strengthSessions: 2, longRunKm: 18.0, deload: false
      ),
      core: [
        DomainModels.PlannedSession(
          card: .longRun,
          tier: .core,
          intensity: .easy,
          isHardDay: false,
          suggestedDay: .sun,
          flags: [.impact]
        ),
      ],
      extras: [],
      targets: DomainModels.WeeklyTargets(
        totalRunKm: 45.0, easyRunRatio: 0.8, strengthSessions: 2, hardDays: 2, cadenceSpm: 178
      ),
      nutrition: DomainModels.WeeklyNutrition(
        proteinG: 170,
        fatGLow: 60,
        fatGHigh: 80,
        hydrationLLow: 2.5,
        hydrationLHigh: 3.5,
        avgCaloriesKcal: 2600,
        dayTypePattern: [
          DomainModels.DayTypePatternEntry(
            suggestedDay: "mon", dayType: .moderate, caloriesKcal: 2600, carbsG: 300
          ),
        ],
        restDay: DomainModels.RestDayNutrition(caloriesKcal: 2200, carbsG: 220),
        lastWeek: DomainModels.LastWeekNutrition(avgCaloriesKcal: 2550, proteinHitDays: 5)
      ),
      constantsRecomputed: false,
      generatedAt: WireFixtures.generatedAt,
      cached: false,
      narrative: [DomainModels.NarrativeSection(type: .plan, heading: "Week 24", body: "Build.")]
    )
  }
}
