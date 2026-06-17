import DesignSystem
import SwiftUI

/// Primitive gallery page — the `NumericStepper` large-numeral counter (`Strength Input Screen.png`)
/// across its min / a mid value / max, so the `−`-disabled-at-min, the wide 3-digit numeral, and the
/// `+`-disabled-at-max states all render. The matrix is short, so the page is its own snapshot section
/// (`NumericStepperSection`).
struct NumericStepperPage: View {
  var body: some View {
    GalleryScaffold(title: "NumericStepper") {
      NumericStepperSection()
    }
  }
}

/// The device-fitting NumericStepper matrix — snapshotted directly (not via the scrolling page).
struct NumericStepperSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      ForEach([0, 42, 300], id: \.self) { value in
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          stateLabel("value = \(value)")
          NumericStepper(value: .constant(value))
            .padding(CoachSpacing.spaceMd)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
            )
        }
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}
