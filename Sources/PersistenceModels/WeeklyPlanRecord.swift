import Foundation
import GRDB

/// The cached weekly plan — keyed by `isoWeek`; `weekStart`/`constantsRecomputed`/`generatedAt`/
/// `cached` are stamps and `body` is the serialized `DomainModels.WeeklyPlan`.
public struct WeeklyPlanRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "weeklyPlan"

  public var isoWeek: String
  public var weekStart: Date
  public var constantsRecomputed: Bool
  public var generatedAt: Date
  public var cached: Bool
  public var body: Data

  public init(
    isoWeek: String,
    weekStart: Date,
    constantsRecomputed: Bool,
    generatedAt: Date,
    cached: Bool,
    body: Data
  ) {
    self.isoWeek = isoWeek
    self.weekStart = weekStart
    self.constantsRecomputed = constantsRecomputed
    self.generatedAt = generatedAt
    self.cached = cached
    self.body = body
  }
}
