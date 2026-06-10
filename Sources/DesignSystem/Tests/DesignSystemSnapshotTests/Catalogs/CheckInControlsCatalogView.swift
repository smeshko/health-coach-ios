import DesignSystem
import SwiftUI

/// Snapshot fixture for the check-in input controls (`1 · Daily Check-in.png`): the `YesNoToggle` in
/// both states and the `SegmentStepper` + `PainSeverity` badge across representative values. Its own
/// catalog (not the atoms grid) so both controls render fully on the reference device rather than below
/// the fold.
struct CheckInControlsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        Text("YesNoToggle").font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
        HStack(spacing: CoachSpacing.spaceSm) {
          YesNoToggle(isOn: .constant(true))
          YesNoToggle(isOn: .constant(false))
        }
      }
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        Text("SegmentStepper + severity badge").font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
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
