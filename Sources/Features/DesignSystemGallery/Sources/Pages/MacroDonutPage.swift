import DesignSystem
import SwiftUI

/// Primitive gallery page — the `MacroDonut` segmented ring. Shows a 3-macro split with a kcal center
/// (the fuel-donut shape), an even 4-way split (equal arcs), and a single segment that fills the ring.
/// Colors are arbitrary here; the macro→color mapping belongs to `NutritionGauge`.
///
/// The matrix fits one device frame, so the page wraps a single device-fitting section
/// (`MacroDonutSection`) that the snapshot tests render directly (not the scrolling page).
struct MacroDonutPage: View {
  var body: some View {
    GalleryScaffold(title: "MacroDonut") {
      MacroDonutSection()
    }
  }
}

/// The device-fitting `MacroDonut` matrix — three segment configurations on surface cards.
struct MacroDonutSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      stateLabel("3-macro split (with center)")
      donutSectionCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 660, color: .coachAccent),
          .init(id: 1, weight: 840, color: .coachWarning),
          .init(id: 2, weight: 650, color: .coachNegative),
        ]) {
          VStack(spacing: 0) {
            Text("2,180")
              .font(.coachText2xl)
              .foregroundStyle(.coachForeground)
            Text("kcal")
              .font(.coachTextXs)
              .foregroundStyle(.coachForegroundMuted)
          }
        }
        .frame(maxWidth: .infinity, alignment: .center)
      }

      stateLabel("Even split (equal arcs)")
      donutSectionCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
          .init(id: 1, weight: 1, color: .coachWarning),
          .init(id: 2, weight: 1, color: .coachNegative),
          .init(id: 3, weight: 1, color: .coachInfo),
        ])
        .frame(maxWidth: .infinity, alignment: .center)
      }

      stateLabel("Single segment (fills the ring)")
      donutSectionCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
        ])
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(.coachBackground)
  }
}

/// Centers a donut on a surface card so the ring shows on its real product surface.
@ViewBuilder
private func donutSectionCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(CoachSpacing.spaceLg)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
