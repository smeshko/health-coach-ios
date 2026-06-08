import Foundation

/// The daily macro focus (`openapi.yaml` `MacroFocus`). Hydration is a `Double` litre range.
public struct MacroFocus: Codable, Sendable, Equatable {
  public var dayType: WireEnum<DayType>
  public var caloriesKcal: Int
  public var proteinG: Int
  public var carbsG: Int
  public var fatGLow: Int
  public var fatGHigh: Int
  public var hydrationLLow: Double
  public var hydrationLHigh: Double

  public init(
    dayType: WireEnum<DayType>,
    caloriesKcal: Int,
    proteinG: Int,
    carbsG: Int,
    fatGLow: Int,
    fatGHigh: Int,
    hydrationLLow: Double,
    hydrationLHigh: Double
  ) {
    self.dayType = dayType
    self.caloriesKcal = caloriesKcal
    self.proteinG = proteinG
    self.carbsG = carbsG
    self.fatGLow = fatGLow
    self.fatGHigh = fatGHigh
    self.hydrationLLow = hydrationLLow
    self.hydrationLHigh = hydrationLHigh
  }
}
