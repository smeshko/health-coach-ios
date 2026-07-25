import Foundation

/// The `coachapp://` deep-link vocabulary (Phase 21.1, DECISIONS D5) — the single contract between
/// the widgets' `widgetURL`s and `AppFeature`'s routing. Lives bottom-of-graph in CoachCore because
/// WidgetsUI cannot import AppFeature; both sides use these constants, never re-typed literals.
/// `checkIn` routes to the Today tab (its `checkInRequired` gate IS the check-in flow); the distinct
/// case exists so 21.5 can specialise behaviour without a new URL contract.
public enum CoachDeepLink: Equatable, Sendable, CaseIterable {
  case today, weekly, checkIn

  /// The registered URL scheme (`CFBundleURLTypes` in App/Info.plist).
  public static let scheme = "coachapp"

  /// The canonical URL per case — host-based, lowercase.
  public var url: URL {
    // Force-unwrap: fixed, valid literal URLs.
    switch self {
    case .today: URL(string: "coachapp://today")!
    case .weekly: URL(string: "coachapp://weekly")!
    case .checkIn: URL(string: "coachapp://checkin")!
    }
  }

  /// Case-insensitive scheme + host match; `nil` for anything else.
  public init?(url: URL) {
    guard url.scheme?.lowercased() == Self.scheme else { return nil }
    switch url.host?.lowercased() {
    case "today": self = .today
    case "weekly": self = .weekly
    case "checkin": self = .checkIn
    default: return nil
    }
  }
}
