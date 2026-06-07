import CoachCore
import Foundation
import GRDB

/// The sync watermark — a singleton row (fixed primary key `id == 1`) holding the last HealthKit
/// anchor, the server time of the last successful sync, and the year-qualified ISO week of the last
/// *synced* strength test.
public struct SyncWatermarkRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "syncWatermark"

  /// Singleton primary key — there is only ever one watermark row.
  public var id: Int
  public var anchor: String?
  public var serverTime: Date
  /// The year-qualified ISO week of the last *synced* strength test (Phase 4.3 — gates "attach a
  /// strength test only when due"). `nil` = none synced yet. A nested `Codable` value, so GRDB stores
  /// it as JSON in the additive `lastStrengthTestSyncedWeek` column.
  public var lastStrengthTestSyncedWeek: ISOWeek?

  public init(
    id: Int = 1,
    anchor: String?,
    serverTime: Date,
    lastStrengthTestSyncedWeek: ISOWeek? = nil
  ) {
    self.id = id
    self.anchor = anchor
    self.serverTime = serverTime
    self.lastStrengthTestSyncedWeek = lastStrengthTestSyncedWeek
  }

  /// Map a domain watermark into the singleton record.
  public init(domain: SyncWatermark) {
    self.init(
      anchor: domain.anchor,
      serverTime: domain.serverTime,
      lastStrengthTestSyncedWeek: domain.lastStrengthTestSyncedWeek
    )
  }

  /// Reconstruct the domain watermark.
  public func toDomain() -> SyncWatermark {
    SyncWatermark(
      anchor: anchor,
      serverTime: serverTime,
      lastStrengthTestSyncedWeek: lastStrengthTestSyncedWeek
    )
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
  public var lastStrengthTestSyncedWeek: ISOWeek?

  public init(anchor: String?, serverTime: Date, lastStrengthTestSyncedWeek: ISOWeek? = nil) {
    self.anchor = anchor
    self.serverTime = serverTime
    self.lastStrengthTestSyncedWeek = lastStrengthTestSyncedWeek
  }
}
