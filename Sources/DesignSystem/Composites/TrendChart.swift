import SwiftUI

/// A trend chart — a `BarColumns` series framed by four corner labels, the shape behind the "Weight"
/// and "Cadence ramp" cards (`docs/design/design-system/chart-1.png`, `charts-2.png`). The bars run
/// left → right with the most-recent (highlighted) bar last; the four labels read in a 2×2 grid around
/// the row:
///
/// - **value** (top-left) — the headline figure + `unit` (e.g. `78.4` · `kg`). Foreground number,
///   muted unit.
/// - **trend** (top-right) — the accent change caption (`slow recomp`, `+5 spm`).
/// - **start** (bottom-left) — the muted baseline reference (`81.0 kg in March`, `started at 158`).
/// - **now** (bottom-right) — the accent "current" reference (`78.4 kg now`, `+5 every 3 wks`).
///
/// `values` are the relative bar heights: pass equal values for a flat series, an ascending ramp for a
/// climb. The highlighted bar and the two accent captions all share `highlightColor`, so recoloring the
/// chart recolors them together; the remaining bars use `trackColor`. The card chrome (title, pill,
/// surface, padding) is owned by the caller — this view is just the bars and their four labels.
public struct TrendChart: View {
  let values: [CGFloat]
  let highlightedIndex: Int
  let trackColor: Color
  let highlightColor: Color
  let value: String
  let unit: String
  let trend: String
  let start: String
  let now: String

  /// - Parameters:
  ///   - values: relative bar heights (equal for a flat series, ascending for a ramp).
  ///   - highlightedIndex: the bar drawn in `highlightColor`; defaults to the last (most recent).
  ///   - trackColor: fill for the non-highlighted bars.
  ///   - highlightColor: fill for the highlighted bar and the two accent captions.
  public init(
    values: [CGFloat],
    value: String,
    unit: String,
    trend: String,
    start: String,
    now: String,
    highlightedIndex: Int? = nil,
    trackColor: Color = .coachAccentSoft,
    highlightColor: Color = .coachAccent
  ) {
    self.values = values
    self.value = value
    self.unit = unit
    self.trend = trend
    self.start = start
    self.now = now
    self.highlightedIndex = highlightedIndex ?? max(values.count - 1, 0)
    self.trackColor = trackColor
    self.highlightColor = highlightColor
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      HStack(alignment: .lastTextBaseline) {
        // Headline: a bold foreground figure with a smaller muted unit on its baseline.
        HStack(alignment: .lastTextBaseline, spacing: CoachSpacing.space2xs) {
          Text(value)
            .font(.coachText2xl)
            .foregroundStyle(.coachForeground)
          Text(unit)
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        Spacer(minLength: CoachSpacing.spaceMd)
        Text(trend)
          .font(.coachTextLg)
          .foregroundStyle(highlightColor)
      }
      BarColumns(bars: bars)
      HStack(alignment: .firstTextBaseline) {
        Text(start)
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
        Spacer(minLength: CoachSpacing.spaceMd)
        Text(now)
          .font(.coachTextSm)
          .foregroundStyle(highlightColor)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var bars: [BarColumns.Bar] {
    values.enumerated().map { index, barValue in
      BarColumns.Bar(value: barValue, color: index == highlightedIndex ? highlightColor : trackColor)
    }
  }
}
