import SwiftUI

/// A thin vertical indicator that floats over a track (`ZoneBar`/`ReadinessBar`) to mark a position.
/// The bar is `$fg`; the glow is the per-use override (tinted to the zone/band it marks).
public struct Marker: View {
  public let glow: Color

  public init(glow: Color) {
    self.glow = glow
  }

  public var body: some View {
    RoundedRectangle(cornerRadius: ComponentMetrics.markerRadius)
      .fill(CoachColor.foreground)
      .frame(width: ComponentMetrics.markerWidth, height: ComponentMetrics.markerHeight)
      .shadow(color: glow, radius: 6)
  }
}
