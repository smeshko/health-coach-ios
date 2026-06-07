import Foundation

/// The weekly nutrition plan (`openapi.yaml` `WeeklyNutrition`).
public struct WeeklyNutrition: Codable, Sendable, Equatable {
  public var proteinG: Int
  public var fatGLow: Int
  public var fatGHigh: Int
  public var hydrationLLow: Double
  public var hydrationLHigh: Double
  public var avgCaloriesKcal: Int
  public var dayTypePattern: [DayTypePatternEntry]
  public var restDay: RestDayNutrition?
  public var lastWeek: LastWeekNutrition?

  public init(
    proteinG: Int,
    fatGLow: Int,
    fatGHigh: Int,
    hydrationLLow: Double,
    hydrationLHigh: Double,
    avgCaloriesKcal: Int,
    dayTypePattern: [DayTypePatternEntry],
    restDay: RestDayNutrition? = nil,
    lastWeek: LastWeekNutrition? = nil
  ) {
    self.proteinG = proteinG
    self.fatGLow = fatGLow
    self.fatGHigh = fatGHigh
    self.hydrationLLow = hydrationLLow
    self.hydrationLHigh = hydrationLHigh
    self.avgCaloriesKcal = avgCaloriesKcal
    self.dayTypePattern = dayTypePattern
    self.restDay = restDay
    self.lastWeek = lastWeek
  }
}

/// One day-type nutrition pattern entry (`openapi.yaml` `DayTypePatternEntry`). `suggestedDay`
/// here is a **free** string (unlike `PlannedSession.suggestedDay`).
public struct DayTypePatternEntry: Codable, Sendable, Equatable {
  public var suggestedDay: String
  public var dayType: WireEnum<DayType>
  public var caloriesKcal: Int
  public var carbsG: Int

  public init(suggestedDay: String, dayType: WireEnum<DayType>, caloriesKcal: Int, carbsG: Int) {
    self.suggestedDay = suggestedDay
    self.dayType = dayType
    self.caloriesKcal = caloriesKcal
    self.carbsG = carbsG
  }
}

/// Rest-day nutrition (`openapi.yaml` `RestDayNutrition`).
public struct RestDayNutrition: Codable, Sendable, Equatable {
  public var caloriesKcal: Int
  public var carbsG: Int

  public init(caloriesKcal: Int, carbsG: Int) {
    self.caloriesKcal = caloriesKcal
    self.carbsG = carbsG
  }
}

/// Last week's nutrition adherence (`openapi.yaml` `LastWeekNutrition`) — all fields optional.
public struct LastWeekNutrition: Codable, Sendable, Equatable {
  public var avgCaloriesKcal: Int?
  public var avgProteinG: Int?
  public var proteinHitDays: Int?
  public var daysOverTarget: Int?
  public var daysUnderTarget: Int?

  public init(
    avgCaloriesKcal: Int? = nil,
    avgProteinG: Int? = nil,
    proteinHitDays: Int? = nil,
    daysOverTarget: Int? = nil,
    daysUnderTarget: Int? = nil
  ) {
    self.avgCaloriesKcal = avgCaloriesKcal
    self.avgProteinG = avgProteinG
    self.proteinHitDays = proteinHitDays
    self.daysOverTarget = daysOverTarget
    self.daysUnderTarget = daysUnderTarget
  }
}
