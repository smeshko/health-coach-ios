import Foundation

/// The daily macro focus.
public struct MacroFocus: Equatable, Sendable {
  public var dayType: DayType
  public var caloriesKcal: Int
  public var proteinG: Int
  public var carbsG: Int
  public var fatGLow: Int
  public var fatGHigh: Int
  public var hydrationLLow: Double
  public var hydrationLHigh: Double

  public init(
    dayType: DayType,
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

/// The weekly nutrition plan. Carries the constant targets (no per-day calories/carbs — those live
/// on `MacroFocus` / `RestDayNutrition` / `DayTypePatternEntry`).
public struct WeeklyNutrition: Equatable, Sendable {
  public var proteinG: Int
  public var fatGLow: Int
  public var fatGHigh: Int
  public var hydrationLLow: Double
  public var hydrationLHigh: Double
  public var avgCaloriesKcal: Int
  /// Day-type pattern — guaranteed non-optional, defaults to empty.
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
    dayTypePattern: [DayTypePatternEntry] = [],
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

/// One day-type nutrition pattern entry. `suggestedDay` is a free string here (not the `Weekday`
/// enum) — it mirrors the wire `type: string` field.
public struct DayTypePatternEntry: Equatable, Sendable {
  public var suggestedDay: String
  public var dayType: DayType
  public var caloriesKcal: Int
  public var carbsG: Int

  public init(suggestedDay: String, dayType: DayType, caloriesKcal: Int, carbsG: Int) {
    self.suggestedDay = suggestedDay
    self.dayType = dayType
    self.caloriesKcal = caloriesKcal
    self.carbsG = carbsG
  }
}

/// Rest-day nutrition.
public struct RestDayNutrition: Equatable, Sendable {
  public var caloriesKcal: Int
  public var carbsG: Int

  public init(caloriesKcal: Int, carbsG: Int) {
    self.caloriesKcal = caloriesKcal
    self.carbsG = carbsG
  }
}

/// Last week's nutrition adherence — all fields nullable (`nil` = no logged coverage; do not
/// default to 0, the UI renders that differently).
public struct LastWeekNutrition: Equatable, Sendable {
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

/// The weekly training budgets.
public struct WeeklyBudgets: Equatable, Sendable {
  public var hardDays: Int
  public var strengthSessions: Int
  public var longRunKm: Double?
  public var deload: Bool

  public init(hardDays: Int, strengthSessions: Int, longRunKm: Double? = nil, deload: Bool) {
    self.hardDays = hardDays
    self.strengthSessions = strengthSessions
    self.longRunKm = longRunKm
    self.deload = deload
  }
}

/// The weekly training targets.
public struct WeeklyTargets: Equatable, Sendable {
  public var totalRunKm: Double?
  public var easyRunRatio: Double
  public var strengthSessions: Int
  public var hardDays: Int
  public var cadenceSpm: Int

  public init(
    totalRunKm: Double? = nil,
    easyRunRatio: Double,
    strengthSessions: Int,
    hardDays: Int,
    cadenceSpm: Int
  ) {
    self.totalRunKm = totalRunKm
    self.easyRunRatio = easyRunRatio
    self.strengthSessions = strengthSessions
    self.hardDays = hardDays
    self.cadenceSpm = cadenceSpm
  }
}
