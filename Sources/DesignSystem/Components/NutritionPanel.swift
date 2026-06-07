import DomainModels
import SwiftUI

/// The daily nutrition panel — the `DayType` prominently (via `DayTypeTag`), the calories, then the
/// macros as a 2×2 grid of `MacroRow`s: **protein emphasized** (the daily constant), carbs, **fat as a
/// range**, **hydration as a range** (`RangeFormatter`, e.g. `65–80 g` / `2.5–3.2 L`), §7.4.4.
public struct NutritionPanel: View {
  public let focus: MacroFocus

  public init(focus: MacroFocus) {
    self.focus = focus
  }

  private let columns = [
    GridItem(.flexible(), spacing: CoachSpacing.space8),
    GridItem(.flexible(), spacing: CoachSpacing.space8),
  ]

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space16) {
      HStack {
        DayTypeTag(dayType: focus.dayType)
        Spacer(minLength: 0)
      }
      HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.space4) {
        Text("\(focus.caloriesKcal)").font(CoachFont.displayNumerals).foregroundStyle(CoachColor.foreground)
        Text("kcal").font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foregroundMuted)
      }
      LazyVGrid(columns: columns, spacing: CoachSpacing.space8) {
        MacroRow(label: "Protein", value: "\(focus.proteinG) g", emphasis: true)
        MacroRow(label: "Carbs", value: "\(focus.carbsG) g")
        MacroRow(label: "Fat", value: RangeFormatter.string(low: focus.fatGLow, high: focus.fatGHigh, unit: "g"))
        MacroRow(
          label: "Hydration",
          value: RangeFormatter.string(low: focus.hydrationLLow, high: focus.hydrationLHigh, unit: "L")
        )
      }
    }
    .padding(CoachSpacing.space16)
    .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(CoachColor.surface))
    .overlay(RoundedRectangle(cornerRadius: CoachRadius.card).stroke(CoachColor.border, lineWidth: 1))
  }
}
