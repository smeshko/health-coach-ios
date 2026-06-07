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
}
