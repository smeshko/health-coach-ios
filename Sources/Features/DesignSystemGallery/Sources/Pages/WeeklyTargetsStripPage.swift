import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `WeeklyTargetsStrip` (the "Weekly targets" section of the 2026-06-10
/// "This Week · Exercise" design): a **full** strip (total km + the 80% easy split + strength + hard days
/// + cadence) and a **nil-`totalRunKm`** strip (the km cell omitted — a week with no run card planned).
struct WeeklyTargetsStripPage: View {
  var body: some View {
    GalleryScaffold(title: "WeeklyTargetsStrip") {
      stateLabel("Full · total km + 80% easy split + strength + hard days + cadence")
      WeeklyTargetsStripFullSection()
      stateLabel("No run planned · totalRunKm nil (km cell omitted)")
      WeeklyTargetsStripNoRunSection()
    }
  }
}

/// The full strip — a non-nil `totalRunKm` and a typical 80/20 split.
struct WeeklyTargetsStripFullSection: View {
  var body: some View {
    weeklyTargetsSectionColumn {
      WeeklyTargetsStrip(
        targets: WeeklyTargets(
          totalRunKm: 38, easyRunRatio: 0.8, strengthSessions: 2, hardDays: 2, cadenceSpm: 180
        )
      )
    }
  }
}

/// The nil-`totalRunKm` strip — no run card planned, so the km cell is omitted (never "nil km").
struct WeeklyTargetsStripNoRunSection: View {
  var body: some View {
    weeklyTargetsSectionColumn {
      WeeklyTargetsStrip(
        targets: WeeklyTargets(
          totalRunKm: nil, easyRunRatio: 0.75, strengthSessions: 3, hardDays: 1, cadenceSpm: 172
        )
      )
    }
  }
}

@ViewBuilder
private func weeklyTargetsSectionColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceMd)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
