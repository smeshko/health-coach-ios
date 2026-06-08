import Foundation

/// A daily Apple activity ring summary (`openapi.yaml` `ActivitySummary`). `date` is a calendar
/// `date` (``WireCalendarDate``).
public struct ActivitySummary: Codable, Sendable, Equatable {
  public var date: WireCalendarDate
  public var activeEnergyKcal: Double
  public var exerciseMinutes: Int
  public var standHours: Int
  public var steps: Int?

  public init(
    date: WireCalendarDate,
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
