import DomainModels
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

  /// Serialize a domain weekly plan into a record (key/stamps copied, full value in `body`).
  public init(domain: DomainModels.WeeklyPlan) throws {
    try self.init(
      isoWeek: domain.isoWeek,
      weekStart: domain.weekStart,
      constantsRecomputed: domain.constantsRecomputed,
      generatedAt: domain.generatedAt,
      cached: domain.cached,
      body: DomainBodyCoder.encode(domain)
    )
  }

  /// Reconstruct the domain weekly plan from the serialized `body` (lossless).
  public func toDomain() throws -> DomainModels.WeeklyPlan {
    try DomainBodyCoder.decode(DomainModels.WeeklyPlan.self, from: body)
  }
}
