import DomainModels
import Foundation
import GRDB

/// The cached profile constants — a singleton row (fixed primary key `id == 1`); `body` is the
/// serialized `DomainModels.Profile`, refreshed when the server recomputes constants.
public struct ProfileRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "profile"

  /// Singleton primary key — there is only ever one profile row.
  public var id: Int
  public var constitutionVersion: String
  public var body: Data
  /// The sync watermark `serverTime` visible when this profile was fetched (Phase 19.2 D1). The
  /// cached profile is stale iff this stamp differs from the current watermark `serverTime` — an
  /// equality of two copies of the *server's* clock, immune to device-clock skew. `nil` = fetched
  /// before any sync (or a pre-upgrade row), which reads as stale exactly once when a watermark
  /// exists.
  public var syncServerTime: Date?

  public init(id: Int = 1, constitutionVersion: String, body: Data, syncServerTime: Date? = nil) {
    self.id = id
    self.constitutionVersion = constitutionVersion
    self.body = body
    self.syncServerTime = syncServerTime
  }

  /// Serialize the domain profile into the singleton record.
  public init(domain: DomainModels.Profile, syncServerTime: Date? = nil) throws {
    try self.init(
      constitutionVersion: domain.meta.constitutionVersion,
      body: DomainBodyCoder.encode(domain),
      syncServerTime: syncServerTime
    )
  }

  /// Reconstruct the domain profile from the serialized `body` (lossless).
  public func toDomain() throws -> DomainModels.Profile {
    try DomainBodyCoder.decode(DomainModels.Profile.self, from: body)
  }
}
