import Foundation

/// A morning self-report check-in (domain twin of the wire `DailyCheckin` request member).
///
/// Phase 2.2 builds only response-shape domain types and defers the request members; this is added
/// in Phase 2.3 as the domain peer of `CheckInRecord`. Plain `Equatable`/`Sendable`, no
/// `Codable`/GRDB (keeps Phase 2.2's `DomainModels` invariant).
public struct CheckIn: Equatable, Sendable {
  public var date: Date
  public var giSymptoms: Bool
  public var kneePain: Int
  public var illness: Bool

  public init(date: Date, giSymptoms: Bool, kneePain: Int, illness: Bool) {
    self.date = date
    self.giSymptoms = giSymptoms
    self.kneePain = kneePain
    self.illness = illness
  }
}
