import ComposableArchitecture
import DomainModels

/// The nutrition target sub-component of `TodayFeature` (ARCHITECTURE §4.5, PRD §7.4.4) — the "TODAY'S
/// FUEL" panel (the day's `MacroFocus` target) paired with the `nutrition` narrative under the COACH NOTE
/// eyebrow. **Internal** to `TodayFeature` (D5 — Today-only, never promoted); the parent constructs it
/// from the loaded brief.
///
/// It owns no fetching and no in-screen interaction (the panel + note are read-only), so `Action` is
/// empty and the body is an `EmptyReducer` — exactly like [[SafetyRestComponent]]. The state is a **pure
/// derivation** from the brief: the always-present `macroFocus` target and the **order-preserving**
/// `type == .nutrition` narrative slice. It authors no prose and computes no macro number (principle
/// #4) — the panel renders the `MacroFocus` verbatim and the renderer the narrative verbatim (principle #1).
///
/// **Feature dependency rule (§3):** imports only `ComposableArchitecture` + `DomainModels`. No repository
/// `@Dependency`, no `WireModels`/GRDB/HealthKit.
@Reducer
public struct NutritionComponent {
  @ObservableState
  public struct State: Equatable {
    /// The day's macro target — always present (openapi marks every `macroFocus` field required), so there
    /// is no empty/null path here (unlike the yesterday recap). Rendered by the `NutritionGauge` panel.
    public var macroFocus: DomainModels.MacroFocus
    /// The `type == .nutrition` narrative slice, **in received order**, paired with the panel under the
    /// COACH NOTE eyebrow. Empty ⇒ the panel renders alone (no placeholder prose). Rendered verbatim.
    public var nutritionNarrative: [DomainModels.NarrativeSection]

    public init(
      macroFocus: DomainModels.MacroFocus,
      nutritionNarrative: [DomainModels.NarrativeSection]
    ) {
      self.macroFocus = macroFocus
      self.nutritionNarrative = nutritionNarrative
    }

    /// Derive from the loaded brief — the day's `macroFocus` and the **order-preserving** `.nutrition`
    /// slice (`Array.filter` keeps order; `NarrativeRenderer` renders verbatim and never reorders,
    /// principle #1). The only "logic" is the type filter — no prose authored, no macro number computed.
    public init(brief: DomainModels.DailyBrief) {
      macroFocus = brief.macroFocus
      nutritionNarrative = brief.narrative.filter { $0.type == .nutrition }
    }
  }

  /// No in-screen interaction — the fuel panel + COACH NOTE are render-only (data handed down from the
  /// loaded brief). Empty, like [[SafetyRestComponent]].
  public enum Action: Equatable {}

  public init() {}

  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
