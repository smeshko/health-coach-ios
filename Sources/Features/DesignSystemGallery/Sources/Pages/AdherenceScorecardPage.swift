import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `AdherenceScorecard` last-week retrospective. A **present** scorecard
/// (all fields), a **present** scorecard with some `nil` fields (showing "—"), and the **empty**
/// "not enough data last week" state.
struct AdherenceScorecardPage: View {
  var body: some View {
    GalleryScaffold(title: "AdherenceScorecard") {
      stateLabel("Present · all fields")
      AdherenceScorecardPresentSection()
      stateLabel("Present · some fields nil (—)")
      AdherenceScorecardPartialSection()
      stateLabel("Empty · not enough data last week")
      AdherenceScorecardEmptySection()
    }
  }
}

struct AdherenceScorecardPresentSection: View {
  var body: some View {
    scorecardSectionColumn {
      AdherenceScorecard(.present(
        LastWeekNutrition(
          avgCaloriesKcal: 2380, avgProteinG: 158, proteinHitDays: 4,
          daysOverTarget: 2, daysUnderTarget: 1
        ),
        caloriesTarget: 2450, proteinTarget: 165
      ))
    }
  }
}

struct AdherenceScorecardPartialSection: View {
  var body: some View {
    scorecardSectionColumn {
      AdherenceScorecard(.present(
        LastWeekNutrition(
          avgCaloriesKcal: 2380, avgProteinG: nil, proteinHitDays: nil,
          daysOverTarget: nil, daysUnderTarget: nil
        ),
        caloriesTarget: 2450, proteinTarget: 165
      ))
    }
  }
}

struct AdherenceScorecardEmptySection: View {
  var body: some View {
    scorecardSectionColumn {
      AdherenceScorecard(.empty)
    }
  }
}

@ViewBuilder
private func scorecardSectionColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceLg)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
