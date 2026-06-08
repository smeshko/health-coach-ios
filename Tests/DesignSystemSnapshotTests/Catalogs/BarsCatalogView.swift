import DesignSystem
import SwiftUI

/// Snapshot fixture for the `SegmentedBar` primitive — every documented shape: HR zones, readiness, the
/// effort range meter, and a weekly streak. Lives in the snapshot-test target (only `BarsSnapshotTests`
/// renders it).
struct BarsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      group("Zones") {
        SegmentedBar.zones(target: 1)
        SegmentedBar.zones(target: 3)
        SegmentedBar.zones(target: 5)
      }
      group("Readiness") {
        SegmentedBar.readiness(score: 20)
        SegmentedBar.readiness(score: 60)
        SegmentedBar.readiness(score: 88)
      }
      group("Effort range") {
        SegmentedBar.range(6 ... 7, total: 10, tone: .warning)
        SegmentedBar.range(1 ... 1, total: 10, tone: .accent)
      }
      group("Weekly streak") {
        SegmentedBar.steps([true, true, true, false, true, true, true], tone: .accent)
        SegmentedBar.steps([true, true, false, true, true, true, false], tone: .warning)
      }
    }
    .padding(CoachSpacing.spaceMd)
    .background(.coachBackground)
  }

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      Text(title).font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
      content()
    }
  }
}
