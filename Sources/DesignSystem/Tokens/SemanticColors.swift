import SwiftUI

/// Tier 2 — Semantic color tokens. Each aliases a Tier-1 primitive (`Colors.swift`) *by role*;
/// components reference these — never a raw primitive or hex. The light/dark `mode` axis is resolved by
/// the OS inside each primitive. Mappings are transcribed from the Colors reference's semantic tier.
public extension CoachColor {
  // Text.
  static let foreground = neutral90 // fg
  static let foregroundMuted = neutral60 // fg-muted
  static let foregroundSubtle = neutral40 // fg-subtle

  // Surfaces.
  static let background = neutral10 // bg
  static let surface = neutral0
  static let surfaceSunken = neutral05 // surface-sunken
  static let surfaceRaised = neutralRaised
  static let border = neutral20

  // Accent + status. `*Soft` are the dedicated soft-tint primitives (never an opacity tint of the base).
  static let accent = accent1
  static let accentSoft = accent1Soft
  static let positive = accent1
  static let positiveSoft = accent1Soft
  static let warning = accent2
  static let warningSoft = accent2Soft
  static let negative = accent3
  static let negativeSoft = accent3Soft
  static let info = accent5

  /// Text/icons on an accent fill. Always the static white so contrast holds in both modes.
  static let onAccent = staticWhite
}

/// Domain color aliases — tokens named by *role*, not hue (PRD §12). HR zones map onto the accent ramp
/// (COMPONENTS.md ZoneBar: Z1→accent-5, Z2→accent-1, Z3→accent-2, Z4→accent-4, Z5→accent-3); intensity
/// accents reuse the status ramp (easy→info, quality→negative, recovery→positive). Each is paired with
/// a label/icon at the enum→label boundary so color is never the sole signal.
public extension CoachColor {
  // swiftlint:disable identifier_name
  static let z1 = accent5
  static let z2 = accent1
  static let z3 = accent2
  static let z4 = accent4
  static let z5 = accent3
  // swiftlint:enable identifier_name

  static let easy = accent5 // calm / aerobic  (= info)
  static let quality = accent3 // hard effort     (= negative)
  static let recovery = accent1 // restorative     (= positive)
}

/// Direct `.coach…` color accessors — convenience mirrors of the Tier-2 semantic tokens so call sites can
/// pass a token straight to `.foregroundStyle`, `.fill`, `.background`, `.tint`, etc. without naming
/// `CoachColor` (e.g. `.foregroundStyle(.coachForeground)`). Declared on `ShapeStyle where Self == Color`
/// — the same shape SwiftUI uses for `.red`/`.primary` — so leading-dot resolution works in the
/// `some ShapeStyle` parameter contexts the components use, while `Color.coachAccent` and plain `Color`
/// value contexts keep resolving too. These forward to the semantics above (the single source of truth)
/// and deliberately expose **only** the semantic/domain roles, never a raw Tier-1 primitive. Mirrors the
/// `Font.Weight.coach…` precedent in `Typography.swift`.
public extension ShapeStyle where Self == Color {
  // Text.
  static var coachForeground: Color { CoachColor.foreground }
  static var coachForegroundMuted: Color { CoachColor.foregroundMuted }
  static var coachForegroundSubtle: Color { CoachColor.foregroundSubtle }

  // Surfaces.
  static var coachBackground: Color { CoachColor.background }
  static var coachSurface: Color { CoachColor.surface }
  static var coachSurfaceSunken: Color { CoachColor.surfaceSunken }
  static var coachSurfaceRaised: Color { CoachColor.surfaceRaised }
  static var coachBorder: Color { CoachColor.border }

  // Accent + status.
  static var coachAccent: Color { CoachColor.accent }
  static var coachAccentSoft: Color { CoachColor.accentSoft }
  static var coachPositive: Color { CoachColor.positive }
  static var coachPositiveSoft: Color { CoachColor.positiveSoft }
  static var coachWarning: Color { CoachColor.warning }
  static var coachWarningSoft: Color { CoachColor.warningSoft }
  static var coachNegative: Color { CoachColor.negative }
  static var coachNegativeSoft: Color { CoachColor.negativeSoft }
  static var coachInfo: Color { CoachColor.info }
  static var coachOnAccent: Color { CoachColor.onAccent }

  // Domain — HR zones (Z1–Z5) and intensity.
  static var coachZ1: Color { CoachColor.z1 }
  static var coachZ2: Color { CoachColor.z2 }
  static var coachZ3: Color { CoachColor.z3 }
  static var coachZ4: Color { CoachColor.z4 }
  static var coachZ5: Color { CoachColor.z5 }
  static var coachEasy: Color { CoachColor.easy }
  static var coachQuality: Color { CoachColor.quality }
  static var coachRecovery: Color { CoachColor.recovery }
}

/// The semantic tone the soft-tint primitives (`Pill`) and the `Chip` flag variant key off. Each tone
/// is a paired `(fill, foreground)` — **never** mix a soft fill with a soft label (a `COMPONENTS.md`
/// rule): the fill is soft, the foreground is the strong color.
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
