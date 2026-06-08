import Foundation

/// A small pure formatter that renders a low/high pair AS a range — one en-dash, one trailing unit
/// (`65–80 g`, `2.5–3.2 L`) — collapsing to a single value when the bounds are equal. Locale-aware
/// number formatting (the decimal separator follows the locale); used by the nutrition fat + hydration
/// ranges so range formatting lives in one unit-tested place (PRD §7.4.4 "show 65–80 g, not a number").
public enum RangeFormatter {
  /// Integer range (e.g. fat grams).
  public static func string(low: Int, high: Int, unit: String) -> String {
    low == high ? "\(low) \(unit)" : "\(low)–\(high) \(unit)"
  }

  /// Decimal range (e.g. hydration litres). `fractionDigits` caps the precision; trailing zeros drop.
  public static func string(
    low: Double,
    high: Double,
    unit: String,
    fractionDigits: Int = 1,
    locale: Locale = .current
  ) -> String {
    let lowText = number(low, fractionDigits: fractionDigits, locale: locale)
    let highText = number(high, fractionDigits: fractionDigits, locale: locale)
    return low == high ? "\(lowText) \(unit)" : "\(lowText)–\(highText) \(unit)"
  }

  private static func number(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = locale
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = false
    return formatter.string(from: value as NSNumber) ?? "\(value)"
  }
}
