import DesignSystem
import SwiftUI

/// Snapshot fixture for the `MacroDonut` primitive — a few segment configurations on a surface card: a
/// 3-macro split with a kcal center (the fuel-donut shape), an even 4-way split, and a single segment that
/// fills the ring. Colors here are arbitrary (the primitive is color-agnostic); the macro→color mapping is
/// the `NutritionGauge`'s job.
struct MacroDonutCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      donutCatalogCard {
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
      }

      donutCatalogCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
          .init(id: 1, weight: 1, color: .coachWarning),
          .init(id: 2, weight: 1, color: .coachNegative),
          .init(id: 3, weight: 1, color: .coachInfo),
        ])
      }

      donutCatalogCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
        ])
      }
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// Centers a donut on a surface card so the ring shows on its real product surface.
@ViewBuilder
private func donutCatalogCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(CoachSpacing.spaceLg)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
