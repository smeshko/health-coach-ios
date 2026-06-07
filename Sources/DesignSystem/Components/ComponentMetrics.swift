import CoreGraphics

/// Intrinsic component geometry that is NOT a spacing/radius token (control heights, bar heights, the
/// marker bar, icon circles) — named constants rather than inline literals (Phase 5.2 Decision 2).
/// Values carried from the `COMPONENTS.md` `.pen` source.
enum ComponentMetrics {
  // Marker.
  static let markerWidth: CGFloat = 4
  static let markerHeight: CGFloat = 18
  static let markerRadius: CGFloat = 2

  // Controls.
  static let primaryButtonHeight: CGFloat = 54
  static let secondaryButtonHeight: CGFloat = 50
  static let segmentHeight: CGFloat = 36

  // Bars.
  static let barSegmentHeight: CGFloat = 10
  static let barWidth: CGFloat = 320
  static let barHeight: CGFloat = 32

  // Chrome.
  static let tabBarHeight: CGFloat = 62
  static let statusBarHeight: CGFloat = 62

  // Day badge.
  static let dayBadgeSize: CGFloat = 30

  // Screen icon circles.
  static let restIconCircle: CGFloat = 96
  static let messageIconCircle: CGFloat = 88

  // RestDay inner shapes.
  static let signalSquare: CGFloat = 40
  static let arrowCircle: CGFloat = 32
}
