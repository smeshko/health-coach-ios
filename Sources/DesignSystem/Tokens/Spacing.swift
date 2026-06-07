import CoreGraphics

/// The 8-leaning spacing scale (the Spacing & Radii reference). Components reference these tokens, not
/// raw point literals. The name encodes the value (the value *is* the semantic for a spacing scale).
public enum CoachSpacing {
  public static let space2: CGFloat = 2
  public static let space4: CGFloat = 4
  public static let space6: CGFloat = 6
  public static let space8: CGFloat = 8
  public static let space10: CGFloat = 10
  public static let space12: CGFloat = 12
  public static let space14: CGFloat = 14
  public static let space16: CGFloat = 16
  public static let space18: CGFloat = 18
  public static let space24: CGFloat = 24
}

/// Corner radii (the Spacing & Radii reference): `sm` 12 · `md` 16 · `card` 24 · `pill` 999 (fully
/// rounded / capsule).
public enum CoachRadius {
  // swiftlint:disable identifier_name
  public static let sm: CGFloat = 12
  public static let md: CGFloat = 16
  // swiftlint:enable identifier_name
  public static let card: CGFloat = 24
  public static let pill: CGFloat = 999
}
