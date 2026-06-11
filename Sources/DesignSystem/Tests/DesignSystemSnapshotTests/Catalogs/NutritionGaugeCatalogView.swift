import DesignSystem
import DomainModels
import SwiftUI

/// Snapshot fixture for the `NutritionGauge` composite — the "TODAY'S FUEL" card on a surface, for the
/// three day types. The moderate-day values mirror `Today · Nutrition.png` (2,180 kcal · 165 g protein ·
/// 210 g carbs · 65–80 g fat · 2.5–3.2 L water).
struct NutritionGaugeCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      gaugeCatalogCard {
        NutritionGauge(focus: MacroFocus(
          dayType: .moderate,
          caloriesKcal: 2180,
          proteinG: 165,
          carbsG: 210,
          fatGLow: 65,
          fatGHigh: 80,
          hydrationLLow: 2.5,
          hydrationLHigh: 3.2
        ))
      }

      gaugeCatalogCard {
        NutritionGauge(focus: MacroFocus(
          dayType: .hard,
          caloriesKcal: 2620,
          proteinG: 175,
          carbsG: 320,
          fatGLow: 70,
          fatGHigh: 85,
          hydrationLLow: 3.0,
          hydrationLHigh: 3.8
        ))
      }

      gaugeCatalogCard {
        NutritionGauge(focus: MacroFocus(
          dayType: .rest,
          caloriesKcal: 1850,
          proteinG: 160,
          carbsG: 140,
          fatGLow: 60,
          fatGHigh: 75,
          hydrationLLow: 2.2,
          hydrationLHigh: 2.8
        ))
      }
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// Wraps the gauge in a surface card (the card chrome the gauge leaves to its caller).
@ViewBuilder
private func gaugeCatalogCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
