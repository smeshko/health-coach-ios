import Foundation

/// The domain outcome of a sync (ARCHITECTURE §7). Mirrors `WireModels.SyncResponse`'s shape but is a
/// **domain** type (no `Codable`, no `WireModels` import). A zero-upsert success is an ordinary
/// `SyncResult` with all counts 0 — **not** an error (PRD §7.1).
public struct SyncResult: Equatable, Sendable {
  public var recordsUpserted: Int
  public var recordsDuplicate: Int
  public var workoutsUpserted: Int
  public var activityDaysUpserted: Int
  public var checkinSaved: Bool
  public var strengthTestSaved: Bool
  public var serverTime: Date

  public init(
    recordsUpserted: Int,
    recordsDuplicate: Int,
    workoutsUpserted: Int,
    activityDaysUpserted: Int,
    checkinSaved: Bool,
    strengthTestSaved: Bool,
    serverTime: Date
  ) {
    self.recordsUpserted = recordsUpserted
    self.recordsDuplicate = recordsDuplicate
    self.workoutsUpserted = workoutsUpserted
    self.activityDaysUpserted = activityDaysUpserted
    self.checkinSaved = checkinSaved
    self.strengthTestSaved = strengthTestSaved
    self.serverTime = serverTime
  }
}
