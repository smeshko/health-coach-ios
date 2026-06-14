import DomainModels
import SwiftUI

/// The "TODAY'S FUEL" card content (`Today · Nutrition.png`): the eyebrow + the `DayType` chip, the
/// `MacroDonut` fuel ring (kcal center + per-macro arcs), and the macro legend. Renders `MacroFocus`
/// only — the kcal figure, the macro grams, and the fat/hydration ranges all come from the model; the
/// donut weights are the kcal contribution of each macro (4·protein + 4·carbs + 9·fat-midpoint). The
/// only authored strings are the per-macro character notes ("hit every day", "the lever", …) and the
/// center carb-character line — fixed DS chrome, not model data.
///
/// The surface/card chrome is owned by the caller (as with `TrendChart`); this view is the eyebrow row,
/// the donut, and the legend.
public struct NutritionGauge: View {
  let focus: MacroFocus

  public init(focus: MacroFocus) {
    self.focus = focus
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      HStack(alignment: .firstTextBaseline) {
        Text("TODAY'S FUEL")
          .font(.coachText2xs)
          .textCase(.uppercase)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundSubtle)
        Spacer(minLength: CoachSpacing.spaceSm)
        Chip(focus.dayType.label)
      }

      HStack(alignment: .center, spacing: CoachSpacing.spaceLg) {
        MacroDonut(
          segments: [
            .init(id: 0, weight: Double(focus.proteinG * Metrics.kcalPerGramProteinCarb), color: .coachAccent),
            .init(id: 1, weight: Double(focus.carbsG * Metrics.kcalPerGramProteinCarb), color: .coachWarning),
            .init(id: 2, weight: fatMidpointG * Double(Metrics.kcalPerGramFat), color: .coachNegative),
          ],
          diameter: Metrics.donutDiameter,
          lineWidth: Metrics.donutLineWidth
        ) {
          VStack(spacing: CoachSpacing.space2xs) {
            Text(focus.caloriesKcal.formatted())
              .font(.coachTextXl)
              .foregroundStyle(.coachForeground)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            Text("kcal")
              .font(.coachTextXs)
              .foregroundStyle(.coachForegroundMuted)
            Text(carbCharacterLine)
              .font(.coachText2xs)
              .foregroundStyle(.coachForegroundSubtle)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          // Keep the center stack inside the ring's inner hole (diameter − both strokes) so the kcal
          // figure and captions never collide with the arc — the donut's fixed frame doesn't clip.
          .frame(maxWidth: Metrics.donutDiameter - Metrics.donutLineWidth * 2)
          .multilineTextAlignment(.center)
        }

        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          LegendRow(
            color: .coachAccent,
            value: "\(focus.proteinG) g",
            name: "Protein",
            note: "hit every day"
          )
          LegendRow(
            color: .coachWarning,
            value: "\(focus.carbsG) g",
            name: "Carbs",
            note: "the lever"
          )
          LegendRow(
            color: .coachNegative,
            value: RangeFormatter.string(low: focus.fatGLow, high: focus.fatGHigh, unit: "g"),
            name: "Fat",
            note: "spread out"
          )
          LegendRow(
            color: .coachInfo,
            value: RangeFormatter.string(low: focus.hydrationLLow, high: focus.hydrationLHigh, unit: "L"),
            name: "Water",
            note: "sip often"
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The fat ring weight uses the range midpoint (the only single value the range affords), kept in grams
  /// so the ×9 kcal scaling reads at the call site.
  private var fatMidpointG: Double {
    Double(focus.fatGLow + focus.fatGHigh) / 2
  }

  /// The center's carb-character line, keyed off the day type (authored DS chrome — the model carries no
  /// such phrase). Mirrors the design's "moderate carbs" caption.
  private var carbCharacterLine: String {
    switch focus.dayType {
    case .hard: "high carbs"
    case .moderate: "moderate carbs"
    case .rest: "low carbs"
    }
  }
}

/// One legend row — a macro's color dot, its value + name on a baseline, and the character note beneath.
private struct LegendRow: View {
  let color: Color
  let value: String
  let name: String
  let note: String

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      Circle()
        .fill(color)
        .frame(width: Metrics.legendDot, height: Metrics.legendDot)
        .padding(.top, Metrics.legendDotTopInset)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.space2xs) {
          Text(value)
            .font(.coachTextLg)
            .foregroundStyle(.coachForeground)
            // Shrink to fit the legend column rather than `fixedSize`, which forced the value to its
            // intrinsic width and could push the whole gauge (and the ScrollView content) wider than the
            // screen on range strings ("1.5–2.0 L") — that horizontal overflow was the Today
            // Exercise↔Nutrition width "jump".
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(name)
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        Text(note)
          .font(.coachText2xs)
          .foregroundStyle(.coachForegroundSubtle)
      }
    }
  }
}

/// Macro kcal factors, the eyebrow tracking, and the legend-dot sizing — named constants, no inline
/// literals.
private enum Metrics {
  static let kcalPerGramProteinCarb = 4
  static let kcalPerGramFat = 9
  static let eyebrowTracking: CGFloat = 0.8
  static let legendDot: CGFloat = 8
  /// Nudges the dot down to sit on the value's cap height.
  static let legendDotTopInset: CGFloat = 6
  /// A smaller ring than the standalone donut default (150) so the legend keeps room beside it.
  static let donutDiameter: CGFloat = 124
  static let donutLineWidth: CGFloat = 16
}
