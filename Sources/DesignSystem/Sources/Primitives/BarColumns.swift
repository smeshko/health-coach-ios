import SwiftUI

/// The vertical bar primitive — a row of rounded columns, each with its own relative height and fill.
/// The column counterpart to `SegmentedBar`: it owns only the bars (no axes, captions, or labels), so a
/// chart frames it with its own text.
///
/// Columns grow up from a shared baseline; heights are normalized against the tallest bar in the set
/// (the tallest fills the track, the rest scale against it), floored at a visible minimum so a rounded
/// column always renders. Each bar carries its own `color` — a highlighted "current" bar is just a bar
/// in a stronger fill, and per-bar colors leave room for more colorful charts later. The row expands to
/// its container's width: every column shares the space left after the inter-column gaps.
public struct BarColumns: View {
  /// One column. `value` is a relative height (normalized against the tallest bar); `color` is the fill.
  public struct Bar {
    public var value: CGFloat
    public var color: Color

    public init(value: CGFloat, color: Color) {
      self.value = value
      self.color = color
    }
  }

  let bars: [Bar]

  public init(bars: [Bar]) {
    self.bars = bars
  }

  // Geometry is design-system-owned (a fixed metric, not a caller knob), matching `SegmentedBar`.
  private var height: CGFloat { Metrics.chartBarsHeight }
  private var cornerRadius: CGFloat { Metrics.chartBarRadius }
  private var gap: CGFloat { CoachSpacing.spaceXs }

  public var body: some View {
    let maxValue = bars.map(\.value).max() ?? 0
    HStack(alignment: .bottom, spacing: gap) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(bar.color)
          .frame(maxWidth: .infinity)
          .frame(height: barHeight(for: bar.value, max: maxValue))
      }
    }
    .frame(height: height, alignment: .bottom)
  }

  /// A bar's point height: its share of the tallest bar, floored at a visible minimum so a rounded
  /// column still renders for a zero/near-zero value.
  private func barHeight(for value: CGFloat, max maxValue: CGFloat) -> CGFloat {
    let floor = cornerRadius * 2
    guard maxValue > 0 else { return floor }
    return Swift.max(height * (value / maxValue), floor)
  }
}

/// Column-row geometry (height of the row, single-column corner radius) — named constants, not literals.
private enum Metrics {
  static let chartBarsHeight: CGFloat = 96
  static let chartBarRadius: CGFloat = 10
}
