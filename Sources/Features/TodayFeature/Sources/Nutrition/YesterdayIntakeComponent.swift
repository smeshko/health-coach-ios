import ComposableArchitecture
import DomainModels

/// The yesterday-intake sub-component of `TodayFeature` (ARCHITECTURE §4.5, PRD §7.4.5) — the
/// intake-vs-target recap for a logged day, and the **first-class "no food logged yesterday" empty state**
/// (§7.4.5/§8.5/§14: not zeros, not an error). **Internal** to `TodayFeature` (D5 — Today-only); the parent
/// constructs it from the loaded brief's `intakeYesterday`.
///
/// Render-only (no fetching, no interaction), so `Action` is empty and the body is an `EmptyReducer` — like
/// [[SafetyRestComponent]]. The only "logic" is a **pure presence check**: a whole-null `intakeYesterday`
/// maps to `.empty`; a present `IntakeSummary` (even one whose macro totals are all nil) maps to
/// `.logged` — the §5 distinction (`IntakeSummary.required: [date, vsTarget]` — every total nullable,
/// `vsTarget` not). No nutrition number is computed (principle #4): the calories % and protein hit/missed
/// are read verbatim from `vsTarget` in the view.
///
/// **Feature dependency rule (§3):** imports only `ComposableArchitecture` + `DomainModels`.
@Reducer
public struct YesterdayIntakeComponent {
  @ObservableState
  public struct State: Equatable {
    /// `.logged(summary)` vs the no-food `.empty` — derived **once** from the optional so the critical
    /// empty branch is a single typed state value the tests assert directly (DECISIONS #2), never a
    /// view-only `nil` unwrap that could fall through to zeros.
    public var display: DisplayState

    /// Map the optional to the display state: `nil → .empty`, `.some(summary) → .logged(summary)`. A pure
    /// presence check (no numeric math) — the §5 distinction: a present summary with all-nil totals is
    /// still `.logged` (its `vsTarget` recap renders; nil totals are simply omitted).
    public init(intakeYesterday: DomainModels.IntakeSummary?) {
      display = intakeYesterday.map(DisplayState.logged) ?? .empty
    }
  }

  /// The recap vs the no-food empty state — 1-level nested (the type-nesting lint rule), like
  /// `ReadinessComponent.PenaltyRow`.
  public enum DisplayState: Equatable, Sendable {
    case logged(DomainModels.IntakeSummary)
    case empty
  }

  /// No in-screen interaction — the recap + empty state are render-only.
  public enum Action: Equatable {}

  public init() {}

  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
