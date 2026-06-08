import Foundation

/// A workout synced to the backend (`openapi.yaml` `Workout`).
///
/// `type` is a **free** HealthKit string (not typed here — that is Phase 2.2). `start`/`end` are
/// `date-time`; `zoneMinutes` is a free `str → minutes` map; `statistics` defaults to `[]`.
public struct Workout: Codable, Sendable, Equatable {
  public var uuid: String
  public var type: String
  public var start: Date
  public var end: Date
  public var durationS: Double
  public var distanceM: Double?
  public var activeEnergyKcal: Double?
  public var effortScore: Int?
  public var zoneMinutes: [String: Double]?
  public var statistics: [WorkoutStat]

  public init(
    uuid: String,
    type: String,
    start: Date,
    end: Date,
    durationS: Double,
    distanceM: Double? = nil,
    activeEnergyKcal: Double? = nil,
    effortScore: Int? = nil,
    zoneMinutes: [String: Double]? = nil,
    statistics: [WorkoutStat] = []
  ) {
    self.uuid = uuid
    self.type = type
    self.start = start
    self.end = end
    self.durationS = durationS
    self.distanceM = distanceM
    self.activeEnergyKcal = activeEnergyKcal
    self.effortScore = effortScore
    self.zoneMinutes = zoneMinutes
    self.statistics = statistics
  }

  private enum CodingKeys: String, CodingKey {
    case uuid, type, start, end, durationS, distanceM, activeEnergyKcal, effortScore, zoneMinutes, statistics
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try container.decode(String.self, forKey: .uuid)
    type = try container.decode(String.self, forKey: .type)
    start = try container.decode(Date.self, forKey: .start)
    end = try container.decode(Date.self, forKey: .end)
    durationS = try container.decode(Double.self, forKey: .durationS)
    distanceM = try container.decodeIfPresent(Double.self, forKey: .distanceM)
    activeEnergyKcal = try container.decodeIfPresent(Double.self, forKey: .activeEnergyKcal)
    effortScore = try container.decodeIfPresent(Int.self, forKey: .effortScore)
    zoneMinutes = try container.decodeIfPresent([String: Double].self, forKey: .zoneMinutes)
    statistics = try container.decodeIfPresent([WorkoutStat].self, forKey: .statistics) ?? []
  }
}
