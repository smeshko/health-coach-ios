import DesignSystem
import SwiftUI

/// Primitive gallery page — the check-in input controls (`1 · Daily Check-in.png`): the `YesNoToggle`
/// in both states and the `SegmentStepper` + `PainSeverity` badge across representative values. Its own
/// page (not the atoms grid) so both controls render fully on the reference device rather than below the
/// fold. The matrix is short, so the page is its own snapshot section (`CheckInControlsSection`).
struct CheckInControlsPage: View {
  var body: some View {
    GalleryScaffold(title: "Check-in controls") {
      CheckInControlsSection()
    }
  }
}

/// The device-fitting check-in controls matrix — snapshotted directly (not via the scrolling page).
struct CheckInControlsSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        stateLabel("YesNoToggle")
        HStack(spacing: CoachSpacing.spaceSm) {
          YesNoToggle(isOn: .constant(true))
          YesNoToggle(isOn: .constant(false))
        }
      }
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        stateLabel("SegmentStepper + severity badge")
        ForEach([0, 2, 7], id: \.self) { value in
          HStack(spacing: CoachSpacing.spaceSm) {
            Pill(PainSeverity.badge(for: value), tone: .warning)
            SegmentStepper(value: .constant(value))
          }
        }
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}
