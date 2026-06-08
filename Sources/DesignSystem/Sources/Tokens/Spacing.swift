import CoreGraphics

/// The spacing scale (the Spacing & Radii reference): **eight steps on a t-shirt scale**
/// (`space2xs … space3xl`). Components reference a token — never a raw point literal.
public enum CoachSpacing {
  public static let space2xs: CGFloat = 4
  public static let spaceXs: CGFloat = 8
  public static let spaceSm: CGFloat = 12
  public static let spaceMd: CGFloat = 16
  public static let spaceLg: CGFloat = 24
  public static let spaceXl: CGFloat = 32
  public static let space2xl: CGFloat = 48
  public static let space3xl: CGFloat = 64
}

/// Corner radii (the Spacing & Radii reference): `sm` 12 · `md` 16 · `card` 24 · `pill` 999 (fully
/// rounded / capsule).
public enum CoachRadius {
  public static let sm: CGFloat = 12
  public static let md: CGFloat = 16
  public static let card: CGFloat = 24
  public static let pill: CGFloat = 999
}
