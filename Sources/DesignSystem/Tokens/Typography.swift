import SwiftUI

/// Typography tokens (the Typography reference — SF Pro standing in for Inter). The scale tokens use
/// Dynamic Type text styles so they scale with accessibility sizes (PRD §9.4); exposed via `CoachFont`
/// and `Font.coach…`.
public enum CoachFont {
  /// Large display numerals — the readiness score. A deliberately **fixed** large hero size (not a
  /// scaling text style) so the at-a-glance score keeps its designed prominence.
  public static let displayNumerals = Font.system(size: 48, weight: .bold, design: .rounded)
  /// Page hero.
  public static let pageHero = Font.largeTitle.weight(.bold)
  /// Screen title.
  public static let screenTitle = Font.title2.weight(.semibold)
  /// Band / large emphasis label.
  public static let bandLabel = Font.title3.weight(.semibold)
  /// Card headline / name.
  public static let cardHeadline = Font.headline
  /// Coach-note heading.
  public static let coachNoteHeading = Font.headline.weight(.semibold)
  /// Body / narrative text.
  public static let body = Font.body
  /// Secondary meta.
  public static let secondaryMeta = Font.subheadline.weight(.medium)
  /// Data emphasis (numeric callouts).
  public static let dataEmphasis = Font.footnote.weight(.semibold)
  /// Caption.
  public static let caption = Font.caption
  /// Eyebrow (small all-caps label; pair with tracking + uppercasing at the call site).
  public static let eyebrow = Font.caption2.weight(.semibold)
}

public extension Font {
  static let coachDisplayNumerals = CoachFont.displayNumerals
  static let coachPageHero = CoachFont.pageHero
  static let coachScreenTitle = CoachFont.screenTitle
  static let coachBandLabel = CoachFont.bandLabel
  static let coachCardHeadline = CoachFont.cardHeadline
  static let coachCoachNoteHeading = CoachFont.coachNoteHeading
  static let coachBody = CoachFont.body
  static let coachSecondaryMeta = CoachFont.secondaryMeta
  static let coachDataEmphasis = CoachFont.dataEmphasis
  static let coachCaption = CoachFont.caption
  static let coachEyebrow = CoachFont.eyebrow
}
