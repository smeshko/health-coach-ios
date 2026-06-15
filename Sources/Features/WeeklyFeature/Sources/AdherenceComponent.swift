import DesignSystem
import DomainModels

/// The last-week adherence sub-component (§4.5) — a pure state container deriving the explicit
/// present-vs-empty `DisplayState` from `WeeklyNutrition.lastWeek` **once** when populated (the §14 empty
/// state is a single typed value, not a view-only `nil` check — mirrors Phase 8.5's typed empty states),
/// alongside the week's calorie/protein targets the scorecard reads for its "vs target" lines.
public enum AdherenceComponent {
  /// The load-bearing §14 branch: a present last-week object vs the "not enough data" empty state.
  public enum DisplayState: Equatable {
    case present(LastWeekNutrition)
    case empty
  }

  public struct State: Equatable {
    public var displayState: DisplayState
    /// The week's `avgCaloriesKcal` / `proteinG` — the targets the scorecard's "vs target" reads use.
    public var caloriesTarget: Int
    public var proteinTarget: Int

    public init(displayState: DisplayState, caloriesTarget: Int, proteinTarget: Int) {
      self.displayState = displayState
      self.caloriesTarget = caloriesTarget
      self.proteinTarget = proteinTarget
    }

    /// The `DesignSystem` scorecard's view state — `.present(lastWeek, targets)` or `.empty`.
    public var scorecardState: AdherenceScorecard.State {
      switch displayState {
      case let .present(lastWeek):
        .present(lastWeek, caloriesTarget: caloriesTarget, proteinTarget: proteinTarget)
      case .empty:
        .empty
      }
    }
  }

  /// `.present` iff `lastWeek != nil`, else `.empty` — derived once when the plan lands.
  public static func make(from nutrition: WeeklyNutrition) -> State {
    State(
      displayState: nutrition.lastWeek.map(DisplayState.present) ?? .empty,
      caloriesTarget: nutrition.avgCaloriesKcal,
      proteinTarget: nutrition.proteinG
    )
  }
}
