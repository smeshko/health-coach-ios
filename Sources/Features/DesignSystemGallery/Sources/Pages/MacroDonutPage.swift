import DesignSystem
import SwiftUI

/// Primitive gallery page — the `MacroDonut` segmented ring. Shows a 3-macro split with a kcal center
/// (the fuel-donut shape), an even 4-way split (equal arcs), and a single segment that fills the ring.
/// Colors are arbitrary here; the macro→color mapping belongs to `NutritionGauge`.
struct MacroDonutPage: View {
  var body: some View {
    GalleryScaffold(title: "MacroDonut") {
      stateLabel("3-macro split (with center)")
      galleryCard {
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
      galleryCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
          .init(id: 1, weight: 1, color: .coachWarning),
          .init(id: 2, weight: 1, color: .coachNegative),
          .init(id: 3, weight: 1, color: .coachInfo),
        ])
        .frame(maxWidth: .infinity, alignment: .center)
      }

      stateLabel("Single segment (fills the ring)")
      galleryCard {
        MacroDonut(segments: [
          .init(id: 0, weight: 1, color: .coachAccent),
        ])
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
  }
}
