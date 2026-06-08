import Foundation

/// The `/brief/weekly` request body (`openapi.yaml` `WeeklyBriefRequest`).
///
/// `isoWeek` is an optional `YYYY-Www` string (no `format: date`, so it stays a `String`) —
/// absent/`null` means the current week (resolved server-side).
public struct WeeklyBriefRequest: Codable, Sendable, Equatable {
  public var isoWeek: String?

  public init(isoWeek: String? = nil) {
    self.isoWeek = isoWeek
  }
}
