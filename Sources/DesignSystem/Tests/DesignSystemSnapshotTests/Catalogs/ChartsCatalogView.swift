import DesignSystem
import SwiftUI

/// Snapshot fixture for the `BarColumns` primitive — every documented state on a surface card.
struct BarColumnsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      chartCatalogCard { BarColumns(bars: ChartCatalogData.flat) }
      chartCatalogCard { BarColumns(bars: ChartCatalogData.ramp) }
      chartCatalogCard { BarColumns(bars: ChartCatalogData.multitone) }
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// Internal snapshot fixture for the `TrendChart` composite — the two reference shapes plus a recolored
/// variant, each on a surface card like the design references (`chart-1.png`, `charts-2.png`).
struct ChartsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      chartCatalogCard {
        TrendChart(
          values: Array(repeating: 1, count: 8),
          value: "78.4", unit: "kg",
          trend: "slow recomp",
          start: "81.0 kg in March",
          now: "78.4 kg now"
        )
      }
      chartCatalogCard {
        TrendChart(
          values: [0.42, 0.45, 0.58, 0.6, 0.72, 0.74, 0.86, 0.88, 1],
          value: "168", unit: "spm",
          trend: "+5 spm",
          start: "started at 158",
          now: "+5 every 3 wks"
        )
      }
      chartCatalogCard {
        TrendChart(
          values: [0.5, 0.62, 0.55, 0.7, 0.66, 0.8, 0.74, 0.9, 1],
          value: "62", unit: "ml/kg",
          trend: "+3 this block",
          start: "started at 54",
          now: "62 now",
          trackColor: .coachWarningSoft,
          highlightColor: .coachWarning
        )
      }
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// Shared bar fixtures for the catalog (and mirrored by the gallery's `BarColumnsPage`).
private enum ChartCatalogData {
  static var flat: [BarColumns.Bar] {
    (0 ..< 8).map { BarColumns.Bar(value: 1, color: $0 == 7 ? .coachAccent : .coachAccentSoft) }
  }

  static var ramp: [BarColumns.Bar] {
    let heights: [CGFloat] = [0.45, 0.5, 0.62, 0.65, 0.78, 0.82, 0.92, 1]
    return heights.enumerated().map { index, height in
      BarColumns.Bar(value: height, color: index == heights.count - 1 ? .coachAccent : .coachAccentSoft)
    }
  }

  static var multitone: [BarColumns.Bar] {
    [
      BarColumns.Bar(value: 0.5, color: .coachBorder),
      BarColumns.Bar(value: 0.85, color: .coachWarning),
      BarColumns.Bar(value: 0.7, color: .coachAccent),
      BarColumns.Bar(value: 0.65, color: .coachAccent),
      BarColumns.Bar(value: 0.55, color: .coachBorder),
      BarColumns.Bar(value: 0.95, color: .coachWarning),
      BarColumns.Bar(value: 0.5, color: .coachBorder),
    ]
  }
}

/// Wraps catalog content in a surface card (card radius + `spaceLg` padding) so the pale track shows on
/// its real product surface rather than the sunken background.
@ViewBuilder
private func chartCatalogCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
