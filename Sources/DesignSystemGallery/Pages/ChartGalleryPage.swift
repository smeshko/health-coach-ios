import DesignSystem
import SwiftUI

/// Composite gallery page — variations of the `TrendChart` (a `BarColumns` series framed by four corner
/// labels). Each chart sits on a surface card like the design references (`chart-1.png`, `charts-2.png`):
/// a flat trend, an ascending ramp, and a recolored variant proving the highlight + accent captions
/// recolor together.
struct ChartGalleryPage: View {
  var body: some View {
    GalleryScaffold(title: "Chart") {
      stateLabel("Flat trend")
      galleryCard {
        TrendChart(
          values: Array(repeating: 1, count: 8),
          value: "78.4", unit: "kg",
          trend: "slow recomp",
          start: "81.0 kg in March",
          now: "78.4 kg now"
        )
      }

      stateLabel("Ascending ramp")
      galleryCard {
        TrendChart(
          values: [0.42, 0.45, 0.58, 0.6, 0.72, 0.74, 0.86, 0.88, 1],
          value: "168", unit: "spm",
          trend: "+5 spm",
          start: "started at 158",
          now: "+5 every 3 wks"
        )
      }

      stateLabel("Recolored (track + highlight + captions)")
      galleryCard {
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
  }
}
