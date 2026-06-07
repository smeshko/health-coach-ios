import Foundation
import GRDB

/// The sync watermark — a singleton row (fixed primary key `id == 1`) holding the last HealthKit
/// anchor and the server time of the last successful sync.
public struct SyncWatermarkRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "syncWatermark"

  /// Singleton primary key — there is only ever one watermark row.
  public var id: Int
  public var anchor: String?
  public var serverTime: Date

  public init(id: Int = 1, anchor: String?, serverTime: Date) {
    self.id = id
    self.anchor = anchor
    self.serverTime = serverTime
  }

  /// Map a domain watermark into the singleton record.
  public init(domain: SyncWatermark) {
    self.init(anchor: domain.anchor, serverTime: domain.serverTime)
  }

  /// Reconstruct the domain watermark.
  public func toDomain() -> SyncWatermark {
    SyncWatermark(anchor: anchor, serverTime: serverTime)
  }
}

/// The domain value the ``SyncWatermarkRecord`` maps to/from.
///
/// The watermark is a persistence-layer bookkeeping value with no view/reducer consumer, so its
/// domain peer lives here rather than in `DomainModels` (which Phase 2.3 only extends with
/// `CheckIn`/`StrengthTest`).
public struct SyncWatermark: Equatable, Sendable {
  public var anchor: String?
  public var serverTime: Date

  public init(anchor: String?, serverTime: Date) {
    self.anchor = anchor
    self.serverTime = serverTime
  }
}
