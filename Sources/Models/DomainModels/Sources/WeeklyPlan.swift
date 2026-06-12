import Foundation

/// The weekly plan, with the wire `{ data, narrative }` envelope flattened.
public struct WeeklyPlan: Equatable, Codable, Sendable {
  public var isoWeek: String
  public var weekStart: Date
  public var budgets: WeeklyBudgets
  /// Core sessions — guaranteed non-optional, defaults to empty.
  public var core: [PlannedSession]
  /// Extra sessions — guaranteed non-optional, defaults to empty.
  public var extras: [PlannedSession]
  public var targets: WeeklyTargets
  public var nutrition: WeeklyNutrition
  public var constantsRecomputed: Bool
  public var generatedAt: Date
  public var cached: Bool
  /// Narrative — guaranteed non-optional, defaults to empty.
  public var narrative: [NarrativeSection]

  public init(
    isoWeek: String,
    weekStart: Date,
    budgets: WeeklyBudgets,
    core: [PlannedSession] = [],
    extras: [PlannedSession] = [],
    targets: WeeklyTargets,
    nutrition: WeeklyNutrition,
    constantsRecomputed: Bool,
    generatedAt: Date,
    cached: Bool,
    narrative: [NarrativeSection] = []
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
    self.narrative = narrative
  }
}
