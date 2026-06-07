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

  public init(id: Int = 1, constitutionVersion: String, body: Data) {
    self.id = id
    self.constitutionVersion = constitutionVersion
    self.body = body
  }
}
