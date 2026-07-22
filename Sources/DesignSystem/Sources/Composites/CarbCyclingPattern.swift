import DomainModels
import SwiftUI

/// The weekly carb-cycling pattern (the 2026-06-10 "This Week · Nutrition" headline story) — a pure
/// 7-day (Mon–Sun) vertical bar chart of grams of carbs, the value printed atop each bar, colored by day
/// type (carb-load = amber / standard = teal / lower-carb = gray), with a per-type ~kcal legend beneath.
/// Days with a `dayTypePattern` entry place their bar on that day; days without one render the **rest-day
/// cut** from `restDay` (gray) — so the week visibly shows carbs riding up around hard days and down on
/// rest days (§7.5.4).
///
/// Pure presentation: the bar heights are a **ranking of the supplied carb grams** (proportional to the
/// chart's own max), never a re-derivation of any nutrition number (principle #4). Carb/kcal values and
/// day-type labels are rendered verbatim; color/height are paired with the printed numbers + the legend
/// so neither is the sole signal (§9.4).
public struct CarbCyclingPattern: View {
  let dayTypePattern: [DayTypePatternEntry]
  let restDay: RestDayNutrition?

  public init(dayTypePattern: [DayTypePatternEntry], restDay: RestDayNutrition?) {
    self.dayTypePattern = dayTypePattern
    self.restDay = restDay
  }

  public var body: some View {
    let days = resolvedDays
    let maxCarbs = days.compactMap(\.carbsG).max() ?? 0
    // `spaceSm` between chart and legend: the legend rows carry their own vertical padding, so the prior
    // `spaceLg` stacked into too large a gap above the first row (`Week · Nutrition.png`).
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      HStack(alignment: .bottom, spacing: CoachSpacing.spaceXs) {
        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
          Bar(label: day.label, carbsG: day.carbsG, kind: day.kind, maxCarbs: maxCarbs)
        }
      }
      Legend(items: legendItems)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// One resolved Mon–Sun slot: a pattern entry on its day (matched via `entry.weekday` — the domain's
  /// case-insensitive reading of the free string), else the `restDay` cut, else empty.
  private var resolvedDays: [DaySlot] {
    Weekday.allCases.map { weekday in
      let label = String(weekday.label.prefix(2)) // "Mo"/"Tu"/… (2-letter, unambiguous unlike the dot-row)
      if let entry = dayTypePattern.first(where: { $0.weekday == weekday }) {
        return DaySlot(label: label, carbsG: entry.carbsG, kind: .dayType(entry.dayType))
      }
      if let restDay {
        return DaySlot(label: label, carbsG: restDay.carbsG, kind: .dayType(.rest))
      }
      return DaySlot(label: label, carbsG: nil, kind: .empty)
    }
  }

  /// One legend row per day type present (carb-load → standard → lower-carb order), with its ~kcal (the
  /// first entry's verbatim `caloriesKcal` for that type / `restDay.caloriesKcal` — grouped, not averaged).
  private var legendItems: [LegendItem] {
    var items: [LegendItem] = []
    for dayType in [DayType.hard, .moderate, .rest] {
      if let entry = dayTypePattern.first(where: { $0.dayType == dayType }) {
        items.append(LegendItem(dayType: dayType, kcal: entry.caloriesKcal))
      } else if dayType == .rest, let restDay {
        items.append(LegendItem(dayType: .rest, kcal: restDay.caloriesKcal))
      }
    }
    return items
  }
}

/// A day's chart slot — its label, optional carb grams (nil = an empty slot with no `restDay`), and the
/// bar kind (a day-type color, or empty).
private struct DaySlot {
  let label: String
  let carbsG: Int?
  let kind: BarKind
}

private enum BarKind {
  case dayType(DayType)
  case empty
}

/// Maps a day type to its carb-cycling presentation (amber carb-load / teal standard / gray lower-carb).
private extension DayType {
  var carbColor: Color {
    switch self {
    case .hard: .coachWarning
    case .moderate: .coachAccent
    case .rest: .coachForegroundSubtle
    }
  }

  /// The carb characterization + day context shown in the legend (authored chrome over the day type —
  /// the raw `hard`/`moderate`/`rest` key never renders).
  var carbCharacter: (label: String, context: String) {
    switch self {
    case .hard: ("Carb-load", "hard days")
    case .moderate: ("Standard", "easy / strength")
    case .rest: ("Lower-carb", "rest days")
    }
  }
}

/// One bar: the carb value atop a day-type-colored bar (height proportional to the chart's max), the day
/// label beneath. An empty slot (no entry, no `restDay`) renders just the label.
private struct Bar: View {
  let label: String
  let carbsG: Int?
  let kind: BarKind
  let maxCarbs: Int

  var body: some View {
    // A clear gap (`spaceSm`) keeps the day label sitting *beneath* the bar baseline rather than crowding
    // it; the bar group is bottom-pinned in a fixed-height frame so every bar shares one baseline.
    VStack(spacing: CoachSpacing.spaceSm) {
      VStack(spacing: CoachSpacing.space2xs) {
        Spacer(minLength: 0)
        if let carbsG {
          Text("\(carbsG)")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
          RoundedRectangle(cornerRadius: Metrics.barRadius, style: .continuous)
            .fill(color)
            .frame(height: height(for: carbsG))
        }
      }
      .frame(height: Metrics.chartHeight, alignment: .bottom)
      Text(label)
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundSubtle)
    }
    .frame(maxWidth: .infinity)
  }

  private var color: Color {
    switch kind {
    case let .dayType(dayType): dayType.carbColor
    case .empty: .coachBorder
    }
  }

  /// Height proportional to the chart's max carbs, with a visible floor so the shortest bar still reads as
  /// a bar (and a guard against a zero/degenerate span — all-equal carbs render full-height).
  private func height(for carbsG: Int) -> CGFloat {
    guard maxCarbs > 0 else { return Metrics.barMaxHeight }
    let ratio = CGFloat(carbsG) / CGFloat(maxCarbs)
    return max(ratio, Metrics.minRatio) * Metrics.barMaxHeight
  }
}

/// The legend — a colored dot + "Carb-load · hard days" + the ~kcal, one row per present day type.
private struct LegendItem: Identifiable {
  let dayType: DayType
  let kcal: Int
  var id: DayType { dayType }
}

private struct Legend: View {
  let items: [LegendItem]

  var body: some View {
    // Hairline dividers separate the per-type rows (each padded so the rule has breathing room) — the
    // legend reads as a small table of day type → ~kcal, matching `Week · Nutrition.png`.
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        if index > 0 {
          Divider().overlay(.coachBorder)
        }
        HStack(spacing: CoachSpacing.spaceSm) {
          Circle()
            .fill(item.dayType.carbColor)
            .frame(width: Metrics.legendDot, height: Metrics.legendDot)
          VStack(alignment: .leading, spacing: 0) {
            Text(item.dayType.carbCharacter.label)
              .font(.coachTextSm)
              .foregroundStyle(.coachForeground)
            Text(item.dayType.carbCharacter.context)
              .font(.coachTextXs)
              .foregroundStyle(.coachForegroundMuted)
          }
          Spacer(minLength: CoachSpacing.spaceSm)
          Text("~\(Self.grouped(item.kcal)) kcal")
            .font(.coachTextMd)
            .foregroundStyle(.coachForeground)
        }
        .padding(.vertical, CoachSpacing.spaceSm)
      }
    }
  }

  /// "2,650" — a grouped thousands format pinned to `en_US_POSIX` so snapshots stay deterministic.
  private static func grouped(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: value as NSNumber) ?? "\(value)"
  }
}

private enum Metrics {
  static let chartHeight: CGFloat = 132
  static let barMaxHeight: CGFloat = 108
  static let minRatio: CGFloat = 0.16
  static let legendDot: CGFloat = 10
  /// Crisp, slightly-rounded column corners — smaller than `CoachRadius.sm` (12) so short rest-day bars
  /// read as columns standing on the baseline, not floating lozenges (`Week · Nutrition.png`).
  static let barRadius: CGFloat = 6
}
