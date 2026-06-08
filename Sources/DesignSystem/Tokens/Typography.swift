import SwiftUI

/// Typography tokens (the Typography reference). One family — **SF Pro**, the system font (Inter is only
/// the design tool's stand-in). Nine **scale-based** size tokens (`textDisplay … text2xs`) and four
/// weight tokens; names are scale-based, not usage-based. Each size token bakes in its spec point size +
/// default weight via `Font.system(size:weight:)`, which still scales with Dynamic Type (PRD §9.4).
/// Bind `fontSize` + `fontWeight` to these tokens — never a raw number.
public enum CoachFont {
  /// 64 / Bold — hero numerals (readiness score).
  public static let textDisplay = Font.system(size: 64, weight: .bold)
  /// 40 / Bold — page hero.
  public static let text3xl = Font.system(size: 40, weight: .bold)
  /// 30 / Bold — screen title.
  public static let text2xl = Font.system(size: 30, weight: .bold)
  /// 24 / Bold — section & card headline.
  public static let textXl = Font.system(size: 24, weight: .bold)
  /// 17 / Semibold — headings & card names.
  public static let textLg = Font.system(size: 17, weight: .semibold)
  /// 15 / Regular — body & narrative.
  public static let textMd = Font.system(size: 15, weight: .regular)
  /// 13 / Semibold — data & secondary meta.
  public static let textSm = Font.system(size: 13, weight: .semibold)
  /// 12 / Medium — captions & chips.
  public static let textXs = Font.system(size: 12, weight: .medium)
  /// 11 / Bold — eyebrows & micro labels (pair with tracking + uppercasing at the call site).
  public static let text2xs = Font.system(size: 11, weight: .bold)
}

/// Weight tokens — `regular 400 / medium 500 / semibold 600 / bold 700`. Bind `fontWeight` to these,
/// never a raw weight.
public extension Font.Weight {
  static let coachRegular = Font.Weight.regular
  static let coachMedium = Font.Weight.medium
  static let coachSemibold = Font.Weight.semibold
  static let coachBold = Font.Weight.bold
}

/// Direct `Font.coach…` accessors — convenience mirrors of the `CoachFont` scale so call sites can pass a
/// token straight to `.font` without naming `CoachFont` (e.g. `.font(.coachTextLg)`). These forward to
/// the scale above — the single source of truth.
public extension Font {
  static let coachTextDisplay = CoachFont.textDisplay
  static let coachText3xl = CoachFont.text3xl
  static let coachText2xl = CoachFont.text2xl
  static let coachTextXl = CoachFont.textXl
  static let coachTextLg = CoachFont.textLg
  static let coachTextMd = CoachFont.textMd
  static let coachTextSm = CoachFont.textSm
  static let coachTextXs = CoachFont.textXs
  static let coachText2xs = CoachFont.text2xs
}
