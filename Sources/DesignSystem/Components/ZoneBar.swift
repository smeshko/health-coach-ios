import SwiftUI

/// A 5-segment HR zone meter (Z1–Z5) with a `Marker` over the target zone, labels below. The marker is
/// centered on the target segment, computed from the measured track width *and the inter-segment gaps*
/// (`(target−1)·(segW+gap) + segW/2`, where `segW = (width − gap·4)/5`).
public struct ZoneBar: View {
  public let target: Int

  public init(target: Int) {
    self.target = target
  }

  private func zoneColor(_ zone: Int) -> Color {
    switch zone {
    case 1: CoachColor.z1
    case 2: CoachColor.z2
    case 3: CoachColor.z3
    case 4: CoachColor.z4
    default: CoachColor.z5
    }
  }

  public var body: some View {
    let clampedTarget = min(max(target, 1), 5)
    return VStack(spacing: CoachSpacing.space6) {
      GeometryReader { geometry in
        // Segments are equal-width with `space4` gaps, so the marker is centered on the *actual*
        // segment center (accounting for the gaps the layout uses), not an idealized gap-free split.
        let gap = CoachSpacing.space4
        let segmentWidth = (geometry.size.width - gap * 4) / 5
        let centerX = CGFloat(clampedTarget - 1) * (segmentWidth + gap) + segmentWidth / 2
        ZStack(alignment: .leading) {
          HStack(spacing: gap) {
            ForEach(1 ... 5, id: \.self) { zone in
              Capsule().fill(zoneColor(zone))
            }
          }
          .frame(height: ComponentMetrics.barSegmentHeight)
          Marker(glow: zoneColor(clampedTarget))
            .offset(x: centerX - ComponentMetrics.markerWidth / 2)
        }
        .frame(height: ComponentMetrics.barHeight, alignment: .center)
      }
      .frame(height: ComponentMetrics.barHeight)
      HStack(spacing: CoachSpacing.space4) {
        ForEach(1 ... 5, id: \.self) { zone in
          Text("Z\(zone)")
            .font(CoachFont.eyebrow)
            .foregroundStyle(zone == clampedTarget ? zoneColor(zone) : CoachColor.foregroundSubtle)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .frame(width: ComponentMetrics.barWidth)
  }
}
