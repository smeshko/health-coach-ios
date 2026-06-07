import DomainModels
import Foundation
import GRDB

/// A strength benchmark — a flat columnar record keyed by `date` (latest overwrites, PRD §8.6).
public struct StrengthTestRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "strengthTest"

  public var date: Date
  public var maxPushups: Int
  public var maxPullups: Int

  public init(date: Date, maxPushups: Int, maxPullups: Int) {
    self.date = date
    self.maxPushups = maxPushups
    self.maxPullups = maxPullups
  }

  /// Map a domain strength test into a record (straight field copy).
  public init(domain: DomainModels.StrengthTest) {
    self.init(date: domain.date, maxPushups: domain.maxPushups, maxPullups: domain.maxPullups)
  }

  /// Reconstruct the domain strength test (straight field copy).
  public func toDomain() -> DomainModels.StrengthTest {
    DomainModels.StrengthTest(date: date, maxPushups: maxPushups, maxPullups: maxPullups)
  }
}
