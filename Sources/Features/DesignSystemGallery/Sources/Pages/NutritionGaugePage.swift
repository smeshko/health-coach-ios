import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `NutritionGauge` "TODAY'S FUEL" card for the three day types, each on a
/// surface card. The moderate-day values mirror `Today · Nutrition.png`.
struct NutritionGaugePage: View {
  var body: some View {
    GalleryScaffold(title: "NutritionGauge") {
      stateLabel("Moderate day")
      galleryCard {
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

      stateLabel("Hard day")
      galleryCard {
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

      stateLabel("Rest day")
      galleryCard {
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
  }
}
