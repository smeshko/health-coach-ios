import DomainModels
import SwiftUI

/// The single horizontal bar primitive. A row of capsule segments with relative widths and per-segment
/// colors, an optional floating `Marker`, and optional per-segment labels beneath. Every horizontal bar
/// in the system is a configuration of this one component:
///
/// - `.zones(active:)` — a 5-segment HR meter (Z1–Z5), markerless: each active zone is shown in its
///   full zone color, the rest muted to the same color at low opacity.
/// - `.readiness(score:band:)` — a 3-band meter (Recover 50% / Ease Off 25% / Ready 25%) with a
///   marker at the score. The active band is the backend-computed domain `ReadinessBand` — the shape
///   never derives it from the score.
/// - `.range(_:total:tone:)` — a markerless effort meter: `total` equal segments with a contiguous
///   filled range (e.g. an RPE 6–7 target across 1–10).
/// - `.steps(_:tone:)` — a markerless weekly streak: equal segments, each on (a tone) or off (the
///   neutral track).
///
/// The contextual captions seen around the meters (titles, "Effort · 1–10", "6 of 7 days", min/max) are
/// caller-composed — the primitive owns only the track, marker, and per-segment labels.
public struct SegmentedBar: View {
  /// One capsule in the row. `weight` is a relative width (equal segments share the same weight); a
  /// proportional bar varies it. `color` is the fill — a zone/band color, or a tone for "on" vs the
  /// neutral track for "off".
  struct Segment {
    var weight: CGFloat = 1
    var color: Color
  }

  /// A floating marker over the track, placed at `fraction` (0…1) across `segmentIndex`'s width.
  struct MarkerPosition {
    var segmentIndex: Int
    var fraction: CGFloat
    var glow: Color
  }

  /// A label beneath the track. `isActive` raises it to `color` + bold; otherwise it is `fg-subtle`.
  struct SegmentLabel {
    var text: String
    var color: Color
    var isActive = false
    var alignment: Alignment = .center
  }

  let segments: [Segment]
  let marker: MarkerPosition?
  let labels: [SegmentLabel]
  /// `nil` falls back to the chunky markerless-meter height; the markered shapes pass a thinner track.
  let segmentHeight: CGFloat?
  let gap: CGFloat
  let labelSpacing: CGFloat
  let width: CGFloat?

  init(
    segments: [Segment],
    marker: MarkerPosition? = nil,
    labels: [SegmentLabel] = [],
    segmentHeight: CGFloat? = nil,
    gap: CGFloat = CoachSpacing.space2xs,
    labelSpacing: CGFloat = CoachSpacing.space2xs,
    width: CGFloat? = nil
  ) {
    self.segments = segments
    self.marker = marker
    self.labels = labels
    self.segmentHeight = segmentHeight
    self.gap = gap
    self.labelSpacing = labelSpacing
    self.width = width
  }

  public var body: some View {
    // Reserve the marker's clearance height only when a marker is present; markerless meters stay
    // compact at the capsule height.
    let capsuleHeight = segmentHeight ?? Metrics.segmentBarHeight
    let trackHeight = marker == nil ? capsuleHeight : Metrics.barHeight
    VStack(spacing: CoachSpacing.spaceXs) {
      GeometryReader { geometry in
        let widths = segmentWidths(in: geometry.size.width)
        ZStack(alignment: .leading) {
          HStack(spacing: gap) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
              Capsule().fill(segment.color).frame(width: widths[index])
            }
          }
          .frame(height: capsuleHeight)
          if let marker {
            Marker(glow: marker.glow)
              .offset(x: markerX(widths: widths, marker: marker) - Metrics.markerWidth / 2)
          }
        }
        .frame(height: trackHeight, alignment: .center)
      }
      .frame(height: trackHeight)
      if !labels.isEmpty {
        HStack(spacing: labelSpacing) {
          ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
            Text(label.text)
              .font(.coachText2xs)
              .fontWeight(label.isActive ? .bold : .medium)
              .foregroundStyle(label.isActive ? label.color : .coachForegroundSubtle)
              .frame(maxWidth: .infinity, alignment: label.alignment)
          }
        }
      }
    }
    .frame(width: width)
  }

  /// Distribute the measured track width across segments by weight, after removing the inter-segment
  /// gaps so the capsules + gaps sum back to the full width.
  private func segmentWidths(in totalWidth: CGFloat) -> [CGFloat] {
    let totalWeight = segments.reduce(0) { $0 + $1.weight }
    guard totalWeight > 0 else { return segments.map { _ in 0 } }
    let available = totalWidth - gap * CGFloat(max(segments.count - 1, 0))
    return segments.map { available * ($0.weight / totalWeight) }
  }

  /// The marker's x: the start of its segment (past preceding segments + gaps) plus its fractional
  /// offset within that segment's measured width.
  private func markerX(widths: [CGFloat], marker: MarkerPosition) -> CGFloat {
    guard widths.indices.contains(marker.segmentIndex) else { return 0 }
    var originX: CGFloat = 0
    for index in 0 ..< marker.segmentIndex {
      originX += widths[index] + gap
    }
    return originX + widths[marker.segmentIndex] * marker.fraction
  }
}

// MARK: - Named shapes

public extension SegmentedBar {
  /// A 5-segment HR zone meter (Z1–Z5), markerless. Each `active` zone is filled in its full zone
  /// color; every other segment is muted to its own zone color at `zoneMutedOpacity`. The active zones'
  /// labels are raised (bold + colored); the rest stay subtle. `active` may name more than one zone.
  static func zones(active: Set<Int>) -> SegmentedBar {
    let activeZones = Set(active.map { min(max($0, 1), 5) })
    let segments = (1 ... 5).map { zone -> Segment in
      let color = zoneColor(zone)
      return Segment(color: activeZones.contains(zone) ? color : color.opacity(Metrics.zoneMutedOpacity))
    }
    let labels = (1 ... 5).map {
      SegmentLabel(text: "Z\($0)", color: zoneColor($0), isActive: activeZones.contains($0))
    }
    return SegmentedBar(
      segments: segments,
      labels: labels,
      segmentHeight: Metrics.barSegmentHeight
    )
  }

  /// Convenience for the common single-target case (e.g. "Zone · Z2 target").
  static func zones(target: Int) -> SegmentedBar {
    zones(active: [target])
  }

  /// A 3-band readiness meter (Recover 50% / Ease Off 25% / Ready 25%) with the marker at `score`.
  /// The highlighted band is `band` — the backend-computed domain value (banding SSOT), never
  /// re-derived from the score here. Labels and colors are the D19 `ReadinessBand` conformances.
  static func readiness(score: Int, band: ReadinessBand) -> SegmentedBar {
    // Meter order is red → amber → green left-to-right; domain `allCases` is green → amber → red,
    // so the axis keeps its own explicit order.
    let meterOrder: [ReadinessBand] = [.red, .amber, .green]
    let segments = meterOrder.map { Segment(weight: $0.meterFraction, color: $0.color) }
    let labels = meterOrder.map {
      SegmentLabel(text: $0.label, color: $0.color, isActive: $0 == band, alignment: $0.meterAlignment)
    }
    let activeIndex = meterOrder.firstIndex(of: band) ?? 0
    let marker = MarkerPosition(
      segmentIndex: activeIndex, fraction: band.markerProgress(for: score), glow: band.color
    )
    return SegmentedBar(
      segments: segments,
      marker: marker,
      labels: labels,
      segmentHeight: Metrics.barSegmentHeight,
      labelSpacing: 0
    )
  }

  /// A markerless effort meter: `total` equal segments with the contiguous `range` filled in `tone`,
  /// the rest the neutral track. Expands to its container's width.
  static func range(_ range: ClosedRange<Int>, total: Int, tone: Tone) -> SegmentedBar {
    let segments = (1 ... max(total, 1)).map {
      Segment(color: range.contains($0) ? tone.foreground : .coachBorder)
    }
    return SegmentedBar(segments: segments)
  }

  /// A markerless weekly streak: one equal segment per day, each on (`tone`) or off (the neutral
  /// track). Expands to its container's width.
  static func steps(_ days: [Bool], tone: Tone) -> SegmentedBar {
    let segments = days.map { Segment(color: $0 ? tone.foreground : .coachBorder) }
    return SegmentedBar(segments: segments)
  }

  private static func zoneColor(_ zone: Int) -> Color {
    switch zone {
    case 1: .coachZ1
    case 2: .coachZ2
    case 3: .coachZ3
    case 4: .coachZ4
    default: .coachZ5
    }
  }
}

/// Meter geometry for the domain `ReadinessBand` — axis scale and marker placement ONLY. Banding is
/// the backend's (`Readiness.band` is the SSOT, Phase 20.1); labels and colors are the D19
/// conformances in `ClosedEnumLabels`. The axis widths mirror the score scale (Recover 0–50,
/// Ease Off 50–75, Ready 75–100) so the marker lands inside the active band.
private extension ReadinessBand {
  var meterFraction: CGFloat {
    switch self {
    case .red: 0.5
    case .amber, .green: 0.25
    }
  }

  var meterAlignment: Alignment {
    switch self {
    case .red: .leading
    case .amber: .center
    case .green: .trailing
    }
  }

  var axisRange: ClosedRange<CGFloat> {
    switch self {
    case .red: 0 ... 50
    case .amber: 50 ... 75
    case .green: 75 ... 100
    }
  }

  /// The score's progress (0…1) within this band's axis range, used to place the marker inside the
  /// active segment. Clamped to 0…1 so an inconsistent (score, band) payload pins the marker at the
  /// band edge instead of escaping the trusted band's segment.
  func markerProgress(for score: Int) -> CGFloat {
    let progress = (CGFloat(score) - axisRange.lowerBound) / (axisRange.upperBound - axisRange.lowerBound)
    return min(max(progress, 0), 1)
  }
}

// MARK: - Marker

/// A thin vertical indicator that floats over the track to mark a position (the target zone / the
/// readiness score). The bar is `$fg`; the glow is the per-use override, tinted to the band it marks.
/// Used only here, so it lives with `SegmentedBar` rather than in its own file.
private struct Marker: View {
  let glow: Color

  var body: some View {
    RoundedRectangle(cornerRadius: Metrics.markerRadius)
      .fill(.coachForeground)
      .frame(width: Metrics.markerWidth, height: Metrics.markerHeight)
      .shadow(color: glow, radius: 6)
  }
}

/// Bar + marker geometry — named constants, not inline literals. Markered shapes use the thin track
/// (`barSegmentHeight`), reserving `barHeight` for the marker's clearance; markerless meters use the
/// chunkier `segmentBarHeight`. All meters fill their container width (no fixed bar width).
private enum Metrics {
  static let barSegmentHeight: CGFloat = 10
  static let barHeight: CGFloat = 32
  static let segmentBarHeight: CGFloat = 14
  /// Opacity applied to a non-active zone segment (its own zone color, dimmed).
  static let zoneMutedOpacity: CGFloat = 0.2
  static let markerWidth: CGFloat = 4
  static let markerHeight: CGFloat = 18
  static let markerRadius: CGFloat = 2
}
