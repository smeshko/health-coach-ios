import SwiftUI

/// Color tokens (ARCHITECTURE §9, D19), transcribed from the Colors reference
/// (`docs/design/design-system/Section Colors.png`). Two tiers:
///
/// - **Tier 1 — primitives** (this file) hold the raw light/dark hex. Accents are a numbered ramp
///   (`accent1` is the brand primary); neutrals are a 0–90 lightness ramp. No primitive is named after
///   its hue.
/// - **Tier 2 — semantics** (`SemanticColors.swift`) alias these primitives *by role* (`foreground`,
///   `surface`, `accent`, `positive`…). Components use the semantics — never a raw primitive or hex.
///
/// Every token resolves a light **and** dark value via the OS `mode` axis (a UIKit dynamic provider on
/// iOS; the light value on the macOS host) — code-defined rather than an asset catalog (per the
/// original DECISIONS #1 note) so it is compile-safe and host-portable. a11y §9.4: color is never the
/// sole signal, so each band/zone/intensity semantic is paired with a label and/or icon at the
/// enum→label boundary.
public enum CoachColor {
  // MARK: Tier 1 — Primitives · Accents (light · dark)

  public static let accent1 = dynamic(light: 0x2C7A6B, dark: 0x41A18D)
  public static let accent1Soft = dynamic(light: 0xE2EEEA, dark: 0x18302B)
  public static let accent2 = dynamic(light: 0xC68A24, dark: 0xE1A33C)
  public static let accent2Soft = dynamic(light: 0xF4EAD4, dark: 0x33291A)
  public static let accent3 = dynamic(light: 0xBC5639, dark: 0xDA755A)
  public static let accent3Soft = dynamic(light: 0xF2E1DA, dark: 0x36221D)
  public static let accent4 = dynamic(light: 0xDB7A3D, dark: 0xE99157)
  public static let accent5 = dynamic(light: 0x5E97B5, dark: 0x71AAC8)
  public static let accent6 = dynamic(light: 0xB58A4E, dark: 0xCAA06C)

  // MARK: Tier 1 — Primitives · Neutrals (light · dark)

  public static let neutral0 = dynamic(light: 0xFFFFFF, dark: 0x1C1B1F)
  public static let neutral05 = dynamic(light: 0xFAFAF7, dark: 0x161518)
  public static let neutral10 = dynamic(light: 0xF2F1EC, dark: 0x121214)
  public static let neutral20 = dynamic(light: 0xE7E5DE, dark: 0x2C2B30)
  public static let neutral40 = dynamic(light: 0xA2A29C, dark: 0x6C6B71)
  public static let neutral60 = dynamic(light: 0x6E6E73, dark: 0x9D9CA3)
  public static let neutral90 = dynamic(light: 0x1A1A1C, dark: 0xF3F2EE)
  public static let neutralRaised = dynamic(light: 0xFFFFFF, dark: 0x3C3B42)
  public static let neutralInk = dynamic(light: 0x1C1C1E, dark: 0x26262C)
  public static let neutralGlass = dynamic(light: 0xFFFFFF, dark: 0x1F1E22, alpha: 242.0 / 255)
  public static let staticWhite = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)
}

private extension CoachColor {
  /// A color that resolves `light`/`dark` (0xRRGGBB) via the OS appearance, at `alpha` opacity.
  static func dynamic(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
    #if canImport(UIKit)
      return Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(rgb: dark, alpha: alpha) : UIColor(rgb: light, alpha: alpha)
      })
    #else
      return Color(rgb: light, opacity: alpha)
    #endif
  }
}

extension Color {
  /// Build an sRGB color from a `0xRRGGBB` value at `opacity`.
  init(rgb: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((rgb >> 16) & 0xFF) / 255,
      green: Double((rgb >> 8) & 0xFF) / 255,
      blue: Double(rgb & 0xFF) / 255,
      opacity: opacity
    )
  }
}

#if canImport(UIKit)
  import UIKit

  extension UIColor {
    convenience init(rgb: UInt32, alpha: Double = 1) {
      self.init(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: CGFloat(alpha)
      )
    }
  }
#endif
