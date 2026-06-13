import SwiftUI

/// The app's motion vocabulary — one **interaction-class** token per kind of change, each pairing a
/// spring preset (duration + bounce, named constants in the `CoachSpacing`/`CoachRadius` spirit — no
/// literals at call sites) with an explicit Reduce-Motion fallback. Components and features resolve a
/// token to an `Animation?` through `CoachMotion.animation(_:reduceMotion:)` (or the `.coachAnimation`
/// view convenience) instead of reinventing spring parameters per screen.
///
/// **Reduce-Motion is per-class, not blanket.** A crossfade `Animation` is a valid fallback only for an
/// **opacity-domain** change — applied to a *positional* change (a matched-geometry slide, a height
/// expand/collapse, a rotation) it still animates the movement, just with a different curve. So
/// positional classes resolve to `nil` (instant snap) under Reduce Motion; opacity-domain classes get an
/// `easeInOut` crossfade. Each token below documents its animated **domain** so 12.3 consumers can't
/// mis-pair a token with a change of a different domain.
public enum CoachMotion {
  /// An interaction class. Pick the token by *what kind of change* it drives, not by its parameters.
  public enum Token: Sendable, CaseIterable {
    /// **Selection** — a snappy slide between discrete options (SegTabs / toggles).
    /// Domain: **positional** (matched-geometry highlight slide). Reduce Motion → `nil` (instant snap).
    case selection

    /// **Disclosure** — a smooth expand/collapse (a "Why" row's height + chevron rotation).
    /// Domain: **positional** (height + rotation). Reduce Motion → `nil` (instant expand/collapse).
    case disclosure

    /// **Screen change** — a smooth, slightly slower crossfade between lifecycle branches (loading ↔
    /// ready ↔ brief content). Domain: **opacity** (branch crossfades). Reduce Motion → `easeInOut`
    /// crossfade (a curve swap that still only changes opacity, so it stays honest).
    case screenChange

    /// **Pressed** — quick button press feedback (scale + opacity dim).
    /// Domain: **opacity + scale**. Reduce Motion → the **opacity leg only** (`CoachPressableStyle`
    /// drops the scale; the resolved animation still drives the surviving opacity dim).
    case pressed
  }

  /// Spring parameters per class — named constants, never inline literals at call sites.
  private enum Spring {
    /// Selection: short + a modest bounce so the slide reads as snappy.
    static let selectionDuration: TimeInterval = 0.3
    static let selectionBounce: Double = 0.2

    /// Disclosure: medium, no bounce — a calm expand/collapse.
    static let disclosureDuration: TimeInterval = 0.35
    static let disclosureBounce: Double = 0

    /// Screen change: slightly longer, no bounce — a settled lifecycle crossfade.
    static let screenChangeDuration: TimeInterval = 0.4
    static let screenChangeBounce: Double = 0

    /// Pressed: very quick, no bounce — immediate tactile feedback that springs back.
    static let pressedDuration: TimeInterval = 0.2
    static let pressedBounce: Double = 0
  }

  /// The opacity-domain Reduce-Motion crossfade duration (used by `screenChange`).
  private enum Fallback {
    static let crossfadeDuration: TimeInterval = 0.2
  }

  /// The full-motion spring for a token (the value used when Reduce Motion is **off**).
  private static func spring(for token: Token) -> Animation {
    switch token {
    case .selection:
      .spring(duration: Spring.selectionDuration, bounce: Spring.selectionBounce)
    case .disclosure:
      .spring(duration: Spring.disclosureDuration, bounce: Spring.disclosureBounce)
    case .screenChange:
      .spring(duration: Spring.screenChangeDuration, bounce: Spring.screenChangeBounce)
    case .pressed:
      .spring(duration: Spring.pressedDuration, bounce: Spring.pressedBounce)
    }
  }

  /// Resolve a token to the animation to apply. With `reduceMotion: false` every token returns its
  /// spring; with `reduceMotion: true` it returns the **complete, pinned** fallback (DECISIONS D1):
  ///
  /// | Token         | Domain          | Reduce-Motion fallback              |
  /// |---------------|-----------------|-------------------------------------|
  /// | `selection`   | positional      | `nil` (instant snap)                |
  /// | `disclosure`  | positional      | `nil` (instant expand/collapse)     |
  /// | `screenChange`| opacity         | `easeInOut` crossfade               |
  /// | `pressed`     | opacity + scale | `easeInOut` (opacity leg only)      |
  ///
  /// Takes `reduceMotion` as a plain `Bool` so the table is unit-testable without UI automation and so
  /// DesignSystem stays TCA-free; the environment read lives only in `.coachAnimation`.
  public static func animation(_ token: Token, reduceMotion: Bool) -> Animation? {
    guard reduceMotion else { return spring(for: token) }
    switch token {
    case .selection, .disclosure:
      return nil
    case .screenChange, .pressed:
      return .easeInOut(duration: Fallback.crossfadeDuration)
    }
  }
}

public extension View {
  /// Apply a `CoachMotion` token's resolved animation, scoped to `value`, reading the current
  /// `accessibilityReduceMotion` environment (DECISIONS D1). The plain
  /// `CoachMotion.animation(_:reduceMotion:)` is the arm 12.3 features pass into
  /// `store.send(_:animation:)`; this modifier is the view-layer arm.
  func coachAnimation(_ token: CoachMotion.Token, value: some Equatable) -> some View {
    modifier(CoachAnimationModifier(token: token, value: value))
  }
}

/// Reads `accessibilityReduceMotion` and applies the token's resolved animation to `value`. A struct
/// (not a computed `some View`) so the environment read is owned by a real view.
private struct CoachAnimationModifier<V: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let token: CoachMotion.Token
  let value: V

  func body(content: Content) -> some View {
    content.animation(CoachMotion.animation(token, reduceMotion: reduceMotion), value: value)
  }
}
