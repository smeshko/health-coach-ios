import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `CarbCyclingPattern` 7-day carb bar chart (the 2026-06-10 "This Week ·
/// Nutrition" headline). A **with-restDay** chart (hard days carry the highest carbs, the rest-day cut
/// fills the gaps + lowest bars) and a **no-restDay** chart (gaps render as empty slots).
struct CarbCyclingPatternPage: View {
  var body: some View {
    GalleryScaffold(title: "CarbCyclingPattern") {
      stateLabel("With rest-day cut · carbs up on hard days, down on rest")
      CarbCyclingPatternWithRestSection()
      stateLabel("No rest-day data · gaps render as empty slots")
      CarbCyclingPatternNoRestSection()
    }
  }
}

struct CarbCyclingPatternWithRestSection: View {
  var body: some View {
    carbPatternSectionColumn {
      CarbCyclingPattern(
        dayTypePattern: [
          DayTypePatternEntry(suggestedDay: "tue", dayType: .hard, caloriesKcal: 2650, carbsG: 320),
          DayTypePatternEntry(suggestedDay: "wed", dayType: .moderate, caloriesKcal: 2350, carbsG: 250),
          DayTypePatternEntry(suggestedDay: "thu", dayType: .moderate, caloriesKcal: 2350, carbsG: 240),
          DayTypePatternEntry(suggestedDay: "sat", dayType: .hard, caloriesKcal: 2650, carbsG: 340),
        ],
        restDay: RestDayNutrition(caloriesKcal: 2100, carbsG: 150)
      )
    }
  }
}

struct CarbCyclingPatternNoRestSection: View {
  var body: some View {
    carbPatternSectionColumn {
      CarbCyclingPattern(
        dayTypePattern: [
          DayTypePatternEntry(suggestedDay: "tue", dayType: .hard, caloriesKcal: 2650, carbsG: 320),
          DayTypePatternEntry(suggestedDay: "thu", dayType: .moderate, caloriesKcal: 2350, carbsG: 240),
          DayTypePatternEntry(suggestedDay: "sat", dayType: .hard, caloriesKcal: 2650, carbsG: 340),
        ],
        restDay: nil
      )
    }
  }
}

@ViewBuilder
private func carbPatternSectionColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceLg)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
