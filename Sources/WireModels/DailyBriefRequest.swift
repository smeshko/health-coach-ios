import Foundation

/// The `/brief/daily` request body (`openapi.yaml` `DailyBriefRequest`).
///
/// `date` is an optional calendar `date` — absent/`null` means "today" (resolved server-side). The
/// optional ``WireCalendarDate`` round-trips `{}` → `nil` via synthesised `decodeIfPresent`, and
/// encodes as a bare `yyyy-MM-dd` string when present (never a `date-time` instant the server's
/// Pydantic `date` validation would reject).
public struct DailyBriefRequest: Codable, Sendable, Equatable {
  public var date: WireCalendarDate?

  public init(date: WireCalendarDate? = nil) {
    self.date = date
  }
}
