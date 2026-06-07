import Foundation

/// The `/sync` request body — a batch of health data to upsert (`openapi.yaml` `SyncRequest`).
///
/// Every member is optional with a collection/`nil` default, so an empty `{}` body is valid (a
/// custom `init(from:)` supplies the `[]` defaults the synthesised initializer cannot).
public struct SyncRequest: Codable, Sendable, Equatable {
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

  private enum CodingKeys: String, CodingKey {
    case records, workouts, activitySummary, checkin, strengthTest
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    records = try container.decodeIfPresent([HealthRecord].self, forKey: .records) ?? []
    workouts = try container.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
    activitySummary = try container.decodeIfPresent([ActivitySummary].self, forKey: .activitySummary) ?? []
    checkin = try container.decodeIfPresent(DailyCheckin.self, forKey: .checkin)
    strengthTest = try container.decodeIfPresent(StrengthTest.self, forKey: .strengthTest)
  }
}
