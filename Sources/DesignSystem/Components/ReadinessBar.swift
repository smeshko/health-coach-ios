import SwiftUI

/// A continuous bar split into 3 readiness bands (Recover 50% / Ease off 25% / Ready 25%) with a
/// `Marker` at the score. Active band: ≥75 Ready, ≥50 Ease off, else Recover.
public struct ReadinessBar: View {
  public let score: Int

  public init(score: Int) {
    self.score = score
  }

  private enum Band: CaseIterable {
    case recover, easeOff, ready

    var color: Color {
      switch self {
      case .recover: CoachColor.negative
      case .easeOff: CoachColor.warning
      case .ready: CoachColor.positive
      }
    }

    var label: String {
      switch self {
      case .recover: "Recover"
      case .easeOff: "Ease off"
      case .ready: "Ready"
      }
    }

    /// Proportional width of the band (Recover is half; the other two a quarter each).
    var fraction: CGFloat {
      switch self {
      case .recover: 0.5
      case .easeOff, .ready: 0.25
      }
    }
  }

  private var activeBand: Band {
    if score >= 75 { .ready } else if score >= 50 { .easeOff } else { .recover }
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.space6) {
      GeometryReader { geometry in
        let clampedScore = CGFloat(min(max(score, 0), 100))
        ZStack(alignment: .leading) {
          // A CONTINUOUS bar (no inter-band gaps), so the marker's `width·score/100` lands exactly on
          // the band edges (Recover→Ease-off at 50, Ease-off→Ready at 75). Outer ends rounded via clip.
          HStack(spacing: 0) {
            ForEach(Band.allCases, id: \.label) { band in
              Rectangle()
                .fill(band.color)
                .frame(width: geometry.size.width * band.fraction)
            }
          }
          .frame(height: ComponentMetrics.barSegmentHeight)
          .clipShape(Capsule())
          Marker(glow: activeBand.color)
            .offset(x: geometry.size.width * clampedScore / 100 - ComponentMetrics.markerWidth / 2)
        }
        .frame(height: ComponentMetrics.barHeight, alignment: .center)
      }
      .frame(height: ComponentMetrics.barHeight)
      HStack {
        Text(Band.recover.label).frame(maxWidth: .infinity, alignment: .leading)
        Text(Band.easeOff.label).frame(maxWidth: .infinity, alignment: .center)
        Text(Band.ready.label).frame(maxWidth: .infinity, alignment: .trailing)
      }
      .font(CoachFont.eyebrow)
      .foregroundStyle(CoachColor.foregroundSubtle)
    }
    .frame(width: ComponentMetrics.barWidth)
  }
}
