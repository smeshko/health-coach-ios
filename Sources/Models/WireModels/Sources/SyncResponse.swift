import Foundation

/// The `/sync` response (`openapi.yaml` `SyncResponse`). `serverTime` is a `date-time`.
public struct SyncResponse: Codable, Sendable, Equatable {
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
