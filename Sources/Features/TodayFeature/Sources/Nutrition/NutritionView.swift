import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The nutrition target panel (`Today · Nutrition.png`): the "TODAY'S FUEL" card — the `NutritionGauge`
/// donut (kcal center + per-macro ring) and legend (protein/carbs/fat/water with their character notes,
/// fat + hydration as ranges, the day-type chip) on a surface card — followed by the **COACH NOTE** block:
/// the `nutrition` narrative rendered **verbatim** by `NarrativeRenderer` (the eyebrow is the section's
/// `heading`, the design's COACH NOTE treatment; the prose is the model's, principle #1).
///
/// The gauge owns no card chrome (like `TrendChart`), so the surface card is composed here — mirroring the
/// readiness card. An empty narrative slice renders the panel alone (no placeholder prose). This view
/// authors no prose and computes no macro number (§3 / principle #4).
public struct NutritionView: View {
  let store: StoreOf<NutritionComponent>

  public init(store: StoreOf<NutritionComponent>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // The "TODAY'S FUEL" card — the gauge on a surface card (the caller owns the chrome).
      NutritionGauge(focus: store.macroFocus)
        .padding(CoachSpacing.spaceLg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .fill(.coachSurface)
            .overlay(
              RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
                .stroke(.coachBorder, lineWidth: 1)
            )
        )

      // The COACH NOTE block — the nutrition narrative verbatim (the renderer owns the eyebrow from the
      // section heading). An empty slice renders nothing: no placeholder prose (principle #1 / §9.1).
      if !store.nutritionNarrative.isEmpty {
        NarrativeRenderer(store.nutritionNarrative)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
