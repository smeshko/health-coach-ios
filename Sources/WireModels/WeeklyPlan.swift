import Foundation

/// The `/brief/weekly` response (`openapi.yaml` `WeeklyPlan`) — a `data`/`narrative` split.
public struct WeeklyPlan: Codable, Sendable, Equatable {
  public var data: WeeklyPlanData
  public var narrative: [NarrativeSection]

  public init(data: WeeklyPlanData, narrative: [NarrativeSection]) {
    self.data = data
    self.narrative = narrative
  }
}

/// The structured payload of a weekly plan (`openapi.yaml` `WeeklyPlanData`). `isoWeek` is a plain
/// `YYYY-Www` string; `weekStart` is a calendar `date`; `generatedAt` is a `date-time` instant.
public struct WeeklyPlanData: Codable, Sendable, Equatable {
  public var isoWeek: String
  public var weekStart: WireCalendarDate
  public var budgets: WeeklyBudgets
  public var core: [PlannedSession]
  public var extras: [PlannedSession]
  public var targets: WeeklyTargets
  public var nutrition: WeeklyNutrition
  public var constantsRecomputed: Bool
  public var generatedAt: Date
  public var cached: Bool

  public init(
    isoWeek: String,
    weekStart: WireCalendarDate,
    budgets: WeeklyBudgets,
    core: [PlannedSession],
    extras: [PlannedSession],
    targets: WeeklyTargets,
    nutrition: WeeklyNutrition,
    constantsRecomputed: Bool,
    generatedAt: Date,
    cached: Bool
  ) {
    self.isoWeek = isoWeek
    self.weekStart = weekStart
    self.budgets = budgets
    self.core = core
    self.extras = extras
    self.targets = targets
    self.nutrition = nutrition
    self.constantsRecomputed = constantsRecomputed
    self.generatedAt = generatedAt
    self.cached = cached
  }
}
