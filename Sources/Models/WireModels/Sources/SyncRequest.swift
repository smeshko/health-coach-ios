import Foundation

/// The `/sync` request body — a batch of health data to upsert (`openapi.yaml` `SyncRequest`).
///
/// Encode-only (the client never decodes a `/sync` request). Every member defaults to an empty
/// collection / `nil`, so an empty `{}` body is valid.
public struct SyncRequest: Encodable, Sendable, Equatable {
  public var records: [HealthRecord]
  public var workouts: [Workout]
  public var activitySummary: [ActivitySummary]
  public var checkin: DailyCheckin?
  public var strengthTest: StrengthTest?

  public init(
    records: [HealthRecord] = [],
    workouts: [Workout] = [],
    activitySummary: [ActivitySummary] = [],
    checkin: DailyCheckin? = nil,
    strengthTest: StrengthTest? = nil
  ) {
    self.records = records
    self.workouts = workouts
    self.activitySummary = activitySummary
    self.checkin = checkin
    self.strengthTest = strengthTest
  }
}
