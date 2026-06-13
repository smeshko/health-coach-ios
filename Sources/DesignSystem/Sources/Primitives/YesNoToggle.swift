import SwiftUI

/// A compact two-option **Yes / No** control bound to a `Bool` (`true` = "Yes", `false` = "No"). The
/// active segment raises to a surface fill; sized to sit at the trailing edge of a question row. Mirrors
/// `SegTabs`'s capsule/segment construction but boolean and label-only (no icons), compact width.
///
/// **Haptic contract (Phase 12.3, DECISIONS D4):** fires `.selection` on every user tap that *changes* the
/// value — re-tapping the already-active segment is a no-op and stays silent, and **programmatic** binding
/// writes (e.g. `CheckInComponent._currentLoaded` hydrating from the repository) never tick (the tick keys
/// on a private tap counter, not the bound value). Consumers don't add their own selection feedback.
public struct YesNoToggle: View {
  @Binding var isOn: Bool
  /// Increments only on a value-changing user tap (see `setOn`) — the `.selection` haptic trigger, so
  /// programmatic binding writes and no-op re-taps stay silent.
  @State private var tapCount = 0

  public init(isOn: Binding<Bool>) {
    _isOn = isOn
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space2xs) {
      Segment(label: "Yes", isActive: isOn) { setOn(true) }
      Segment(label: "No", isActive: !isOn) { setOn(false) }
    }
    .padding(CoachSpacing.space2xs)
    .background(Capsule().fill(.coachBorder))
    .sensoryFeedback(.selection, trigger: tapCount)
  }

  /// Apply a tapped value, ticking the selection haptic **only** when it actually changes — re-tapping the
  /// active segment is a silent no-op.
  private func setOn(_ newValue: Bool) {
    guard newValue != isOn else { return }
    isOn = newValue
    tapCount += 1
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
      .buttonStyle(.coachPressable)
    }
  }
}

/// Segment sizing — named constants, not inline literals (matches `SegTabs`'s `Metrics`).
private enum Metrics {
  static let segmentWidth: CGFloat = 44
  static let segmentHeight: CGFloat = 32
}
