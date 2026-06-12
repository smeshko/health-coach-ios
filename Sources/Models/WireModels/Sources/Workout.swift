import Foundation

/// A workout synced to the backend (`openapi.yaml` `Workout`).
///
/// `type` is a **free** HealthKit string (not typed here — that is Phase 2.2). `start`/`end` are
/// `date-time`.
public struct Workout: Codable, Sendable, Equatable {
  public var uuid: String
  public var type: String
  public var start: Date
  public var end: Date
  public var durationS: Double
  public var distanceM: Double?
  public var activeEnergyKcal: Double?
  public var effortScore: Int?

  public init(
    uuid: String,
    type: String,
    start: Date,
    end: Date,
    durationS: Double,
    distanceM: Double? = nil,
    activeEnergyKcal: Double? = nil,
    effortScore: Int? = nil
  ) {
    self.uuid = uuid
    self.type = type
    self.start = start
    self.end = end
    self.durationS = durationS
    self.distanceM = distanceM
    self.activeEnergyKcal = activeEnergyKcal
    self.effortScore = effortScore
  }
}
