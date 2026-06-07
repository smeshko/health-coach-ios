import DomainModels
import Foundation
import GRDB

/// A morning check-in — a flat columnar record keyed by `date` (upsert-by-date semantics).
public struct CheckInRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "checkIn"

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

  /// Map a domain check-in into a record (straight field copy).
  public init(domain: DomainModels.CheckIn) {
    self.init(
      date: domain.date,
      giSymptoms: domain.giSymptoms,
      kneePain: domain.kneePain,
      illness: domain.illness
    )
  }

  /// Reconstruct the domain check-in (straight field copy).
  public func toDomain() -> DomainModels.CheckIn {
    DomainModels.CheckIn(date: date, giSymptoms: giSymptoms, kneePain: kneePain, illness: illness)
  }
}
