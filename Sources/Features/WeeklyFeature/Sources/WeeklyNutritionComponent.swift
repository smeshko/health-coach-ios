import DesignSystem
import DomainModels

/// The weekly-nutrition sub-component (§4.5 "internal unless promoted") — a pure state container (like
/// `WeekRhythmComponent`; no interactions on the nutrition tab, so no `@Reducer`). It holds the loaded
/// `WeeklyNutrition` constants/pattern and the order-preserving `type == .nutrition` slice of the plan's
/// narrative (the renderer never self-filters, 5.4 — the feature hands it just that slice). The view layer
/// (`WeeklyNutritionView`) renders the carb-cycling chart + the "Steady all week" constants + the
/// nutrition narrative; no number is computed (principle #4).
public enum WeeklyNutritionComponent {
  public struct State: Equatable {
    public var nutrition: WeeklyNutrition
    /// The `type == .nutrition` narrative slice, in received order.
    public var narrative: [NarrativeSection]

    public init(nutrition: WeeklyNutrition, narrative: [NarrativeSection]) {
      self.nutrition = nutrition
      self.narrative = narrative
    }
  }

  /// Populate from a loaded plan — the constants/pattern come from `plan.nutrition`, the narrative is the
  /// order-preserving `.nutrition` slice of the plan's narrative.
  public static func make(from plan: WeeklyPlan) -> State {
    State(
      nutrition: plan.nutrition,
      narrative: plan.narrative.filter { $0.type == .nutrition }
    )
  }
}
