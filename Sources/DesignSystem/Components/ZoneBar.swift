import SwiftUI

/// A 5-segment HR zone meter (Z1–Z5) with a `Marker` over the target zone, labels below. The marker x
/// is recomputed from the measured track width (`width·(target−0.5)/5`).
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
    VStack(spacing: CoachSpacing.space6) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          HStack(spacing: CoachSpacing.space4) {
            ForEach(1 ... 5, id: \.self) { zone in
              Capsule().fill(zoneColor(zone))
            }
          }
          .frame(height: ComponentMetrics.barSegmentHeight)
          Marker(glow: zoneColor(target))
            .offset(
              x: geometry.size.width * (CGFloat(target) - 0.5) / 5 - ComponentMetrics.markerWidth / 2
            )
        }
        .frame(height: ComponentMetrics.barHeight, alignment: .center)
      }
      .frame(height: ComponentMetrics.barHeight)
      HStack(spacing: CoachSpacing.space4) {
        ForEach(1 ... 5, id: \.self) { zone in
          Text("Z\(zone)")
            .font(CoachFont.eyebrow)
            .foregroundStyle(zone == target ? zoneColor(zone) : CoachColor.foregroundSubtle)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .frame(width: ComponentMetrics.barWidth)
  }
}
