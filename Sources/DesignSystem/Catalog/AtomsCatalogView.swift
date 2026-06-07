import SwiftUI

/// Internal snapshot fixture for the atom/control primitives (Phase 5.2 TASK-001) — every component
/// across its documented states. Not a product screen.
struct AtomsCatalogView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.space16) {
        group("Pill") {
          Pill("Easy", tone: .accent)
          Pill("Threshold", tone: .warning, leading: .dot)
          Pill("Primed", tone: .positive, leading: .icon("checkmark.circle.fill"))
          Pill("STRAINED", tone: .negative, uppercase: true)
        }
        group("Chip") {
          Chip("5 km", leading: .icon("ruler"))
          Chip("RPE 6")
          Chip("Flagged", leading: .dot(CoachColor.warning), textColor: CoachColor.warning)
        }
        group("DayBadge") {
          DayBadge("Mon", tone: .accent, isCore: true)
          DayBadge("Sat", isCore: false)
        }
        group("Marker") {
          Marker(glow: CoachColor.z3)
        }
        VStack(spacing: CoachSpacing.space8) {
          PrimaryButton("Continue", icon: "checkmark") {}
          SecondaryButton("Not now") {}
        }
        SegTabs(selection: .constant(.exercise))
        SegTabs(selection: .constant(.nutrition))
      }
      .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
  }

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space8) {
      Text(title).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
      HStack(spacing: CoachSpacing.space8) { content() }
    }
  }
}
