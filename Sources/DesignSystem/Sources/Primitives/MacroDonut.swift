import SwiftUI

/// A markerless segmented ring — N proportional arcs, each in its own color, with an optional
/// caller-composed center. Weights are **sum-normalized**, so callers pass raw proportions (e.g. kcal per
/// macro) without pre-dividing; arcs start at 12 o'clock, run clockwise, and are separated by a small gap
/// so the wedges read as distinct. The ring expands to a fixed diameter.
///
/// **Pure geometry — no domain knowledge.** The `NutritionGauge` fuel donut (and, later, the weekly
/// nutrition ring) compose it by supplying the per-macro weights, colors, and the kcal center. Markerless
/// and static — no spinner, unlike `SyncProgressView`'s progress ring.
public struct MacroDonut<Center: View>: View {
  /// One proportional ring segment — a relative `weight` and its stroke `color`. Negative weights are
  /// treated as zero; the set is sum-normalized at render.
  public struct Segment: Identifiable {
    public let id: Int
    public let weight: Double
    public let color: Color

    public init(id: Int, weight: Double, color: Color) {
      self.id = id
      self.weight = weight
      self.color = color
    }
  }

  let segments: [Segment]
  let center: Center

  public init(segments: [Segment], @ViewBuilder center: () -> Center) {
    self.segments = segments
    self.center = center()
  }

  public var body: some View {
    ZStack {
      ForEach(arcs) { arc in
        Circle()
          .trim(from: arc.start, to: arc.end)
          .stroke(arc.color, style: StrokeStyle(lineWidth: Metrics.ringWidth, lineCap: .butt))
          .rotationEffect(.degrees(-90)) // trim 0 → 12 o'clock
      }
      center
    }
    .frame(width: Metrics.diameter, height: Metrics.diameter)
  }

  /// Resolved arc spans — each segment's normalized fraction laid end-to-end, inset by half a `gap` on
  /// each side so neighbouring wedges (including the seam at 12 o'clock) read as separate.
  private var arcs: [Arc] {
    let total = segments.reduce(0.0) { $0 + max(0, $1.weight) }
    guard total > 0 else { return [] }
    let gap: CGFloat = segments.count > 1 ? Metrics.gap : 0
    var cursor: CGFloat = 0
    return segments.map { segment in
      let fraction = CGFloat(max(0, segment.weight) / total)
      let start = cursor + gap / 2
      let end = cursor + fraction - gap / 2
      cursor += fraction
      return Arc(id: segment.id, start: min(start, end), end: max(start, end), color: segment.color)
    }
  }

  private struct Arc: Identifiable {
    let id: Int
    let start: CGFloat
    let end: CGFloat
    let color: Color
  }
}

public extension MacroDonut where Center == EmptyView {
  /// A donut with no center content — just the ring.
  init(segments: [Segment]) {
    self.init(segments: segments) { EmptyView() }
  }
}

/// Ring diameter / stroke width / inter-segment gap — named constants (mirrors `SegmentedBar`'s `Metrics`).
private enum Metrics {
  static let diameter: CGFloat = 150
  static let ringWidth: CGFloat = 20
  /// Gap between neighbouring segments, as a fraction of the full circle.
  static let gap: CGFloat = 0.014
}
