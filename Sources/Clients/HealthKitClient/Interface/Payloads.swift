import Foundation
import WireModels

/// A single HealthKit sample, as plain transport data (D11). **Not** a `WireModels` DTO —
/// `SyncRepository` (Epic 4.3) maps these to `WireModels.SyncRequest`. Reuses `RecordType` (an enum)
/// only as a type tag. Allows both the quantity shape (`value` + `unit`) and the category shape
/// (`category`) — every sample field is optional.
public struct HealthRecordPayload: Sendable, Equatable {
  public var uuid: String
  public var type: RecordType
  public var start: Date
  public var end: Date
  public var value: Double?
  public var unit: String?
  public var category: String?
  public var source: String?
  public var metadata: [String: String]?

  public init(
    uuid: String,
    type: RecordType,
    start: Date,
    end: Date,
    value: Double? = nil,
    unit: String? = nil,
    category: String? = nil,
    source: String? = nil,
    metadata: [String: String]? = nil
  ) {
    self.uuid = uuid
    self.type = type
    self.start = start
    self.end = end
    self.value = value
    self.unit = unit
    self.category = category
    self.source = source
    self.metadata = metadata
  }
}

/// A per-workout statistic (HK `type` is a free string).
public struct WorkoutStatPayload: Sendable, Equatable {
  public var type: String
  public var value: Double
  public var unit: String

  public init(type: String, value: Double, unit: String) {
    self.type = type
    self.value = value
    self.unit = unit
  }
}

/// A workout sample as plain transport data.
public struct WorkoutPayload: Sendable, Equatable {
  public var uuid: String
  public var type: String
  public var start: Date
  public var end: Date
  public var durationS: Double
  public var distanceM: Double?
  public var activeEnergyKcal: Double?
  public var effortScore: Int?
  public var zoneMinutes: [String: Double]?
  public var statistics: [WorkoutStatPayload]

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
    statistics: [WorkoutStatPayload] = []
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
}

/// A daily Apple activity-ring summary as plain transport data.
public struct ActivitySummaryPayload: Sendable, Equatable {
  public var date: Date
  public var activeEnergyKcal: Double
  public var exerciseMinutes: Int
  public var standHours: Int
  public var steps: Int?

  public init(
    date: Date,
    activeEnergyKcal: Double,
    exerciseMinutes: Int,
    standHours: Int,
    steps: Int? = nil
  ) {
    self.date = date
    self.activeEnergyKcal = activeEnergyKcal
    self.exerciseMinutes = exerciseMinutes
    self.standHours = standHours
    self.steps = steps
  }
}

/// The aggregate a delta read returns.
public struct HealthSampleSet: Sendable, Equatable {
  public var records: [HealthRecordPayload]
  public var workouts: [WorkoutPayload]
  public var activity: [ActivitySummaryPayload]

  public init(
    records: [HealthRecordPayload] = [],
    workouts: [WorkoutPayload] = [],
    activity: [ActivitySummaryPayload] = []
  ) {
    self.records = records
    self.workouts = workouts
    self.activity = activity
  }

  public static let empty = HealthSampleSet()
}
