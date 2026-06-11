import SwiftUI

/// A compact two-option **Yes / No** control bound to a `Bool` (`true` = "Yes", `false` = "No"). The
/// active segment raises to a surface fill; sized to sit at the trailing edge of a question row. Mirrors
/// `SegTabs`'s capsule/segment construction but boolean and label-only (no icons), compact width.
public struct YesNoToggle: View {
  @Binding var isOn: Bool

  public init(isOn: Binding<Bool>) {
    _isOn = isOn
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space2xs) {
      Segment(label: "Yes", isActive: isOn) { isOn = true }
      Segment(label: "No", isActive: !isOn) { isOn = false }
    }
    .padding(CoachSpacing.space2xs)
    .background(Capsule().fill(.coachBorder))
  }

  /// One option — a label-only button; the active option raises to a surface fill.
  private struct Segment: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Text(label)
          .font(.coachTextSm)
          .foregroundStyle(isActive ? .coachForeground : .coachForegroundMuted)
          .frame(width: Metrics.segmentWidth, height: Metrics.segmentHeight)
          .background(Capsule().fill(isActive ? .coachSurfaceRaised : Color.clear))
      }
      .buttonStyle(.plain)
    }
  }
}

/// Segment sizing — named constants, not inline literals (matches `SegTabs`'s `Metrics`).
private enum Metrics {
  static let segmentWidth: CGFloat = 44
  static let segmentHeight: CGFloat = 32
}
