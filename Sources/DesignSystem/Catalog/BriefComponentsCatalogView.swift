import DomainModels
import SwiftUI

/// Internal snapshot fixtures for the brief components (Phase 5.4 TASK-005) — ReadinessGauge across the
/// three bands, NutritionPanel across the three day types, NarrativeRenderer across all five types.
enum BriefSamples {
  static func readiness(_ score: Int, _ band: ReadinessBand) -> Readiness {
    Readiness(score: score, band: band, penalties: [])
  }

  static func macros(_ dayType: DayType, kcal: Int, protein: Int, carbs: Int) -> MacroFocus {
    MacroFocus(
      dayType: dayType, caloriesKcal: kcal, proteinG: protein, carbsG: carbs,
      fatGLow: 65, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.2
    )
  }

  static let narrative: [NarrativeSection] = [
    NarrativeSection(
      type: .summary, heading: "Today",
      body: "A steady aerobic day. Keep it **easy** and let yesterday settle."
    ),
    NarrativeSection(
      type: .session, heading: "How to run it",
      body: "Warm up, then settle into zone 2:\n- Relaxed shoulders\n- Nose-breathing pace"
    ),
    NarrativeSection(
      type: .nutrition, heading: "Fuel",
      body: "Protein at every meal. Carbs around the run."
    ),
    NarrativeSection(
      type: .caution, heading: "Gentle note",
      body: "Your knee flag is active — stop if it sharpens."
    ),
    NarrativeSection(
      type: .plan, heading: "This week",
      body: "Two quality days, the rest easy. *Consistency over heroics.*"
    ),
  ]
}

struct ReadinessGaugeCatalogView: View {
  var body: some View {
    VStack(spacing: CoachSpacing.space12) {
      ReadinessGauge(readiness: BriefSamples.readiness(86, .green))
      ReadinessGauge(readiness: BriefSamples.readiness(62, .amber))
      ReadinessGauge(readiness: BriefSamples.readiness(34, .red))
    }
    .padding(CoachSpacing.space16)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(CoachColor.background)
  }
}

struct NutritionPanelCatalogView: View {
  var body: some View {
    VStack(spacing: CoachSpacing.space12) {
      NutritionPanel(focus: BriefSamples.macros(.hard, kcal: 2800, protein: 165, carbs: 380))
      NutritionPanel(focus: BriefSamples.macros(.moderate, kcal: 2400, protein: 160, carbs: 280))
      NutritionPanel(focus: BriefSamples.macros(.rest, kcal: 2100, protein: 160, carbs: 180))
    }
    .padding(CoachSpacing.space16)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(CoachColor.background)
  }
}

struct NarrativeRendererCatalogView: View {
  var body: some View {
    ScrollView {
      NarrativeRenderer(sections: BriefSamples.narrative)
        .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
  }
}
