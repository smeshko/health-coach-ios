import ComposableArchitecture
import DomainModels

/// The forced-REST sub-component of `TodayFeature` (ARCHITECTURE §4.5, PRD §7.4.2) — the **render-only**
/// state behind the dedicated calm forced-REST screen ([[SafetyRestView]]). **Internal** to `TodayFeature`
/// (D5 — Today-only, never promoted); the parent constructs it from the loaded brief only on a trip (see
/// [[TodaySessionMode]]).
///
/// It owns no fetching and no in-screen interaction: a forced rest has **no swap/skip** (those are
/// structurally absent, not merely hidden), so `Action` is empty and the body is an `EmptyReducer`. The
/// state is a **pure derivation** from the brief — the tripped `SafetyGate`, the expanded override
/// `SessionBlock` (`brief.session`, *not* `gate.overrideTo`), and the parent-supplied bpm `zoneRange` for
/// the override card's zone chip.
///
/// **Feature dependency rule (§3):** imports only `ComposableArchitecture` + `DomainModels`. No repository
/// `@Dependency`, no `WireModels`/GRDB/HealthKit.
@Reducer
public struct SafetyRestComponent {
  @ObservableState
  public struct State: Equatable {
    /// The tripped gate (`triggered == true`, its `reasons`, the `overrideTo` *name*).
    public var gate: DomainModels.SafetyGate
    /// The deterministic override session — the expanded `brief.session` (a `SessionBlock`), the
    /// rendered form of the gate's `overrideTo` card. **Not** `gate.overrideTo` (a `Card?`).
    public var overrideSession: DomainModels.SessionBlock
    /// The bpm range for the override card's `ZoneChip`, **pre-resolved by the parent** from
    /// `ProfileRepository.zones()` (the component never resolves zones, §3). A single `ZoneRange?`
    /// suffices because a forced rest has no swap (unlike 8.4's full `Zones` map); `nil` ⇒ no chip
    /// (true for `rest`/`mobility` overrides, whose `zoneTarget == nil`).
    public var zoneRange: DomainModels.ZoneRange?

    public init(
      gate: DomainModels.SafetyGate,
      overrideSession: DomainModels.SessionBlock,
      zoneRange: DomainModels.ZoneRange? = nil
    ) {
      self.gate = gate
      self.overrideSession = overrideSession
      self.zoneRange = zoneRange
    }

    /// The calm reason headline(s) — each `gate.reasons` element through the §7.4.2 typed calm-copy switch
    /// (the single translation point, principle #2). An empty/`.unknown` `reasons` list falls back to the
    /// generic graceful line, so the screen never shows a blank headline or a raw key.
    public var reasonHeadlines: [String] {
      gate.reasons.isEmpty
        ? [SafetyReasonCopy.calmCopy(for: .unknown(""))]
        : gate.reasons.map { SafetyReasonCopy.calmCopy(for: $0) }
    }
  }

  /// No in-screen interaction — a forced rest has no swap/skip (those affordances are structurally absent).
  public enum Action: Equatable {}

  public init() {}

  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
