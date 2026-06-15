import DesignSystem
import DomainModels

/// The week-rhythm sub-component (§4.5 "internal unless promoted") — a pure state container + the
/// derivation that places the plan's suggested sessions onto the Mon…Sun dot-row (`WeekRhythmRow`). No
/// interactions, so it is a plain namespace rather than a `@Reducer` (pure state-in/view-out).
///
/// The classification is **pinned** (the 2026-06-10 design's 3-way legend — Hard / Easy / Rest — folds
/// strength into hard/easy by `isHardDay`, so there is no separate "strength" dot): a day is `.hard` when
/// any session suggested for it has `isHardDay == true`, else `.easy` when any session is suggested, else
/// `.rest`. The dot is **filled** (`core: true`) when a *core* session sits that day, **outlined** when
/// only *extras* do. A nil-`suggestedDay` session places no dot. This is presentation derivation (placing
/// the server's suggested days on a row), not health math (principle #4).
public enum WeekRhythmComponent {
  public struct State: Equatable {
    /// The Mon…Sun rhythm (seven entries, positionally paired with `Weekday.allCases`).
    public var days: [WeekRhythmRow.Day]
    /// The week's training budgets, carried for the tone/assertions.
    public var budgets: WeeklyBudgets

    public init(days: [WeekRhythmRow.Day], budgets: WeeklyBudgets) {
      self.days = days
      self.budgets = budgets
    }
  }

  /// Derive the rhythm from a `ready` plan. Collision precedence: a hard session on a day wins over an
  /// easy one (`isHardDay` → `.hard`); core presence wins the fill (a day with both a core and an extra
  /// session is filled).
  public static func rhythm(from plan: WeeklyPlan) -> State {
    let suggested = plan.core.map { ($0, true) } + plan.extras.map { ($0, false) }
    let days = Weekday.allCases.map { weekday -> WeekRhythmRow.Day in
      let onDay = suggested.filter { $0.0.suggestedDay == weekday }
      guard !onDay.isEmpty else { return .rest }
      let isCore = onDay.contains { $0.1 }
      let isHard = onDay.contains { $0.0.isHardDay }
      return isHard ? .hard(core: isCore) : .easy(core: isCore)
    }
    return State(days: days, budgets: plan.budgets)
  }
}
