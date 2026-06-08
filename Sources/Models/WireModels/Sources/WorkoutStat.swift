import Foundation

/// A per-workout statistic (`openapi.yaml` `WorkoutStat`). `type` is a **free** HealthKit string.
public struct WorkoutStat: Codable, Sendable, Equatable {
  public var type: String
  public var value: Double
  public var unit: String

  public init(type: String, value: Double, unit: String) {
    self.type = type
    self.value = value
    self.unit = unit
  }
}
