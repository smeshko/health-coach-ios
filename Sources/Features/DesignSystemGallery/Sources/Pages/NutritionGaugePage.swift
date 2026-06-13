import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `NutritionGauge` "TODAY'S FUEL" card for the three day types, each on a
/// surface card. The moderate-day values mirror `Today · Nutrition.png`.
///
/// Each gauge card is tall (donut + a five-row legend), so the three day types are split across two
/// device-fitting sections — `NutritionGaugeSection` (moderate + hard) and `NutritionGaugeRestSection`
/// (rest) — which the page stacks and the snapshot tests render directly (so nothing clips below the
/// fold).
struct NutritionGaugePage: View {
  var body: some View {
    GalleryScaffold(title: "NutritionGauge") {
      NutritionGaugeSection()
      NutritionGaugeRestSection()
    }
  }
}

/// The moderate + hard day types on surface cards — a device-fitting section.
struct NutritionGaugeSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      stateLabel("Moderate day")
      gaugeSectionCard {
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
      gaugeSectionCard {
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
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(.coachBackground)
  }
}

/// The rest day type on a surface card — a device-fitting section.
struct NutritionGaugeRestSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      stateLabel("Rest day")
      gaugeSectionCard {
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
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(.coachBackground)
  }
}

/// Wraps the gauge in a surface card (the card chrome the gauge leaves to its caller).
@ViewBuilder
private func gaugeSectionCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
