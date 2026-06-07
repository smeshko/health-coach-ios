import SwiftUI

// Semantic + soft-tint tokens the primitives need (Phase 5.2, Decision 4 — added as 5.1-style tokens,
// never a raw hex in a component). `warning`/`negative`/`positive` alias the readiness traffic-light
// colors; the `*Soft` fills are low-opacity tints of their base for soft-tint backgrounds.
public extension CoachColor {
  static let warning = amber
  static let negative = red
  static let positive = green

  static let accentSoft = accent.opacity(0.15)
  static let warningSoft = amber.opacity(0.15)
  static let negativeSoft = red.opacity(0.15)
  static let positiveSoft = green.opacity(0.15)

  /// Translucent fill for the floating glass nav (`TabBar`).
  static let surfaceGlass = surface.opacity(0.72)
  /// The selected-tab capsule fill.
  static let tabSelected = accent.opacity(0.14)
  /// A muted on-accent for sub-labels on accent fills.
  static let onAccentMuted = onAccent.opacity(0.72)
  /// A faint on-accent fill (e.g. the trailing-arrow circle on an accent row).
  static let onAccentSoft = onAccent.opacity(0.15)
  /// The card/nav drop-shadow color (a subtle dark; deliberately the same in both modes).
  static let shadow = Color.black.opacity(0.06)
}

/// The semantic tone the soft-tint primitives (`Pill`, `MessageState`) and the `Chip` flag variant key
/// off. Each tone is a paired `(fill, foreground)` — **never** mix a soft fill with a soft label
/// (a `COMPONENTS.md` rule): the fill is soft, the foreground is the strong color.
public enum Tone: Sendable, CaseIterable {
  case accent
  case warning
  case negative
  case positive

  public var fill: Color {
    switch self {
    case .accent: CoachColor.accentSoft
    case .warning: CoachColor.warningSoft
    case .negative: CoachColor.negativeSoft
    case .positive: CoachColor.positiveSoft
    }
  }

  public var foreground: Color {
    switch self {
    case .accent: CoachColor.accent
    case .warning: CoachColor.warning
    case .negative: CoachColor.negative
    case .positive: CoachColor.positive
    }
  }
}
