import SwiftUI

/// Semantic color tokens (ARCHITECTURE §9, D19). Every token resolves a light **and** dark value via
/// the OS — components never write a raw hex. a11y §9.4: color is never the sole signal, so each
/// band/zone/intensity token is paired with a label and/or icon at the enum→label boundary.
///
/// NOTE: DECISIONS #1 specified an asset catalog. This ships **code-defined dynamic colors** instead —
/// equivalent OS light/dark resolution (a UIKit dynamic provider on iOS; the light value on the macOS
/// host), but compile-safe (no stringly-typed asset lookup) and host-portable (DesignSystem compiles
/// on macOS with no resource bundle). The hex pairs below are transcribed from the Colors reference.
public enum CoachColor {
  // Readiness traffic-light bands.
  public static let green = dynamic(light: 0x2E7D32, dark: 0x6FD175)
  public static let amber = dynamic(light: 0xC97A00, dark: 0xFFC44D)
  public static let red = dynamic(light: 0xC12B2B, dark: 0xFF6B67)

  // Cool → hot HR zone ramp (z1 cool blue → z5 hot red).
  // swiftlint:disable identifier_name
  public static let z1 = dynamic(light: 0x3F72C4, dark: 0x6E9BE8)
  public static let z2 = dynamic(light: 0x2F9E9E, dark: 0x4FD0D0)
  public static let z3 = dynamic(light: 0x6E9E2F, dark: 0x9FD45A)
  public static let z4 = dynamic(light: 0xD08A1E, dark: 0xF2B04A)
  public static let z5 = dynamic(light: 0xC12B2B, dark: 0xFF6B67)
  // swiftlint:enable identifier_name

  // Intensity accents.
  public static let easy = dynamic(light: 0x3F72C4, dark: 0x6E9BE8)
  public static let quality = dynamic(light: 0xC12B2B, dark: 0xFF6B67)
  public static let recovery = dynamic(light: 0x2F9E9E, dark: 0x4FD0D0)

  // Brand accent.
  public static let accent = dynamic(light: 0x4C5FFF, dark: 0x8E9BFF)
  public static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0E122A)

  // Neutrals + surfaces.
  public static let background = dynamic(light: 0xF7F7F9, dark: 0x101216)
  public static let surface = dynamic(light: 0xFFFFFF, dark: 0x1B1E24)
  public static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x242830)
  public static let border = dynamic(light: 0xE2E3E8, dark: 0x343842)
  public static let foreground = dynamic(light: 0x14161C, dark: 0xF2F3F7)
  public static let foregroundMuted = dynamic(light: 0x5C606B, dark: 0xA6ABB6)
  public static let foregroundSubtle = dynamic(light: 0x8A8F9A, dark: 0x737985)
}

private extension CoachColor {
  /// A color that resolves `light`/`dark` (0xRRGGBB) via the OS appearance.
  static func dynamic(light: UInt32, dark: UInt32) -> Color {
    #if canImport(UIKit)
      return Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
      })
    #else
      return Color(rgb: light)
    #endif
  }
}

extension Color {
  /// Build an opaque sRGB color from a `0xRRGGBB` value.
  init(rgb: UInt32) {
    self.init(
      .sRGB,
      red: Double((rgb >> 16) & 0xFF) / 255,
      green: Double((rgb >> 8) & 0xFF) / 255,
      blue: Double(rgb & 0xFF) / 255,
      opacity: 1
    )
  }
}

#if canImport(UIKit)
  import UIKit

  extension UIColor {
    convenience init(rgb: UInt32) {
      self.init(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
      )
    }
  }
#endif
