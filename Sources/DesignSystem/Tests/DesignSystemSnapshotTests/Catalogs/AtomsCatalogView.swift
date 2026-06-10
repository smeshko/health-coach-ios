import DesignSystem
import SwiftUI

/// Snapshot fixture for the atom/control primitives — every component across its documented states. Not
/// a product screen; lives in the snapshot-test target since only `AtomsSnapshotTests` renders it.
struct AtomsCatalogView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        group("Pill") {
          Pill("Easy", tone: .accent)
          Pill("Threshold", tone: .warning, leading: .dot)
          Pill("Primed", tone: .positive, leading: .icon("checkmark.circle.fill"))
          Pill("STRAINED", tone: .negative, uppercase: true)
        }
        group("Chip") {
          Chip("5 km", leading: .icon("ruler"))
          Chip("RPE 6")
          Chip("Flagged", leading: .dot(.coachWarning), textColor: .coachWarning)
        }
        group("DayBadge") {
          DayBadge("Tue", tone: .negative, isCore: true)
          DayBadge("Fri", tone: .warning, isCore: false)
        }
        group("IconBadge") {
          IconBadge("drop", shape: .square, size: .lg, tone: .accent)
          IconBadge("drop", shape: .circle, size: .lg, tone: .accent)
          IconBadge("exclamationmark.triangle.fill", tone: .warning)
          IconBadge("xmark", tone: .negative)
        }
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          Text("Banner").font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
          Banner(
            icon: "info.circle", tone: .accent,
            title: "It's been a week since your last test",
            message: "Log today's numbers to keep the trend honest."
          )
          Banner(
            icon: "exclamationmark.triangle.fill", tone: .warning,
            title: "Heads up — gut sensitivity flagged",
            message: "Favor low-residue meals around today's run."
          )
        }
        VStack(spacing: CoachSpacing.spaceXs) {
          PrimaryButton("Continue", icon: "checkmark") {}
          SecondaryButton("Not now") {}
        }
        SegTabs(selection: .constant(.exercise))
        SegTabs(selection: .constant(.nutrition))
        group("YesNoToggle") {
          YesNoToggle(isOn: .constant(true))
          YesNoToggle(isOn: .constant(false))
        }
      }
      .padding(CoachSpacing.spaceMd)
    }
    .background(.coachBackground)
  }

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
      Text(title).font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
      HStack(spacing: CoachSpacing.spaceXs) { content() }
    }
  }
}
