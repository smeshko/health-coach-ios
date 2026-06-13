import SwiftUI

/// The shared press-feedback `ButtonStyle`: while held, the label scales to `Metrics.pressedScale` and
/// dims to `Metrics.pressedOpacity` on the `CoachMotion.Token.pressed` spring, springing back on release.
/// Under Reduce Motion the **scale leg is dropped** and only the opacity dim remains (feedback without
/// motion) — the `pressed` token still resolves to an animation (the opacity domain), so the dim is
/// animated, not snapped.
///
/// It deliberately does **NOT** add a background, a border, or change the hit-target — it is *purely*
/// press feedback layered on whatever the label already draws. So swapping it in for `.buttonStyle(.plain)`
/// is visually identical **at rest** (snapshot-safe); only the pressed/animated states differ.
public struct CoachPressableStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      // Reduce Motion drops the scale leg (no motion); the opacity dim always applies.
      .scaleEffect(scale(isPressed: configuration.isPressed))
      .opacity(configuration.isPressed ? Metrics.pressedOpacity : 1)
      .animation(CoachMotion.animation(.pressed, reduceMotion: reduceMotion), value: configuration.isPressed)
  }

  private func scale(isPressed: Bool) -> CGFloat {
    guard isPressed, !reduceMotion else { return 1 }
    return Metrics.pressedScale
  }

  /// Press-feedback magnitudes — named constants, not inline literals.
  private enum Metrics {
    static let pressedScale: CGFloat = 0.97
    static let pressedOpacity: Double = 0.85
  }
}

public extension ButtonStyle where Self == CoachPressableStyle {
  /// Press feedback only (no background / hit-target change), so it reads `.buttonStyle(.coachPressable)`
  /// at call sites — drop-in for `.plain` on a custom-labelled button.
  static var coachPressable: CoachPressableStyle { CoachPressableStyle() }
}
