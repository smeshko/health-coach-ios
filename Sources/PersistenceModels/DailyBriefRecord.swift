import DomainModels
import Foundation
import GRDB

/// The cached daily brief — a thin keyed record (DECISIONS #2). Keyed by `date` (the Europe/Sofia
/// day); `cached`/`generatedAt`/`constitutionVersion` are queryable stamps and `body` is the
/// serialized `DomainModels.DailyBrief` (the lossless source for `toDomain()`, added in TASK-004).
public struct DailyBriefRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "dailyBrief"

  public var date: Date
  public var cached: Bool
  public var generatedAt: Date
  public var constitutionVersion: String?
  public var body: Data

  public init(date: Date, cached: Bool, generatedAt: Date, constitutionVersion: String?, body: Data) {
    self.date = date
    self.cached = cached
    self.generatedAt = generatedAt
    self.constitutionVersion = constitutionVersion
    self.body = body
  }

  /// Serialize a domain daily brief into a record (key/stamps copied, full value in `body`).
  public init(domain: DomainModels.DailyBrief) throws {
    try self.init(
      date: domain.date,
      cached: domain.cached,
      generatedAt: domain.generatedAt,
      constitutionVersion: domain.constitutionVersion,
      body: DomainBodyCoder.encode(domain)
    )
  }

  /// Reconstruct the domain daily brief from the serialized `body` (lossless).
  public func toDomain() throws -> DomainModels.DailyBrief {
    try DomainBodyCoder.decode(DomainModels.DailyBrief.self, from: body)
  }
}
