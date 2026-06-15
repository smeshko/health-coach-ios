import ComposableArchitecture
import DomainModels

/// The shared **daily session** feature (ARCHITECTURE §4.5 / D5 — the promoted hybrid component in its own
/// target) — a `@Reducer` rendering the daily `SessionBlock`s through the `DesignSystem` `SessionCard` as a
/// **horizontal carousel** of candidates (`[session] + alternatives`), with **tap-to-commit** selection and
/// the warm permission-to-skip affordance.
///
/// **Parent-supplied input, no repository.** Every field of `State` is handed in by the parent
/// (`TodayFeature`): the primary `session`, its `alternatives`, the `skipOk` flag, the `.session`-typed
/// `narrative` slice, and the full `Zones` map. The feature reaches **no** repository, data-source client,
/// `WireModels`, GRDB, or HealthKit (§3/§4.5) — it imports only `ComposableArchitecture` + `DomainModels`
/// (the view adds `SwiftUI` + `DesignSystem`). Selection is **display-only** here: it changes which
/// already-supplied block is the committed pick and emits `delegate(.selectionChanged)`; the parent owns
/// persistence (DECISIONS D5). There is no network/server re-roll (PRD §7.4.3, DECISIONS #1).
///
/// **Daily-only.** The 2026-06-10 design iteration makes the weekly rows a distinct compact presentation,
/// so Weekly renders a pure `WeeklySessionRow` (Phase 9.2) and never embeds this feature — there is no
/// `.weekly` input or initializer here or later.
@Reducer
public struct SessionFeature {
  @ObservableState
  public struct State: Equatable {
    /// The **primary** (server-recommended) daily session — candidate index 0, the "Suggested" card.
    public var session: SessionBlock
    /// The ≤2 validated substitutes from the brief (may be empty — forced-REST or none offered), the
    /// "Alternative" cards at candidate indices 1…n.
    public var alternatives: [SessionBlock]
    /// Whether to surface the warm "skipping is fine today" affordance.
    public var skipOk: Bool
    /// The `type == .session` narrative slice (pre-filtered by the parent, DECISIONS #3); rendered
    /// **inside** the card's narrative slot per the 2026-06-10 iteration.
    public var narrative: [NarrativeSection]
    /// The **full** five-zone bpm map (`ProfileRepository.zones()` returns the whole map, not a single
    /// range), passed in by the parent so `zoneRange(for:)` resolves each candidate's zone correctly
    /// (DECISIONS #4). The feature never resolves zones itself (§3/D19).
    public var zones: Zones?
    /// **Local UI** committed selection by **index** into `candidates` (`0` = the primary). Defaults to
    /// `0` (primary pre-selected, DECISIONS D2); the parent re-seeds it from today's persisted pick on
    /// hydrate (DECISIONS D4/D5). 2.2's `SessionBlock` carries no stable `ID`, so selection is positional
    /// here and persisted **by value** upstream.
    public var selectedIndex: Int

    public init(
      session: SessionBlock,
      alternatives: [SessionBlock] = [],
      skipOk: Bool = false,
      narrative: [NarrativeSection] = [],
      zones: Zones? = nil,
      selectedIndex: Int = 0
    ) {
      self.session = session
      self.alternatives = alternatives
      self.skipOk = skipOk
      self.narrative = narrative
      self.zones = zones
      self.selectedIndex = selectedIndex
    }

    /// All candidate sessions in carousel order — the primary first, then the alternatives. A computed
    /// projection over stored state, so `Equatable`/TestStores stay byte-identical.
    public var candidates: [SessionBlock] {
      [session] + alternatives
    }

    /// The committed pick — the in-range `candidates[selectedIndex]`, else the primary. A stale/out-of-range
    /// index (e.g. after a refreshed brief re-supplies a shorter `alternatives`) falls back to the primary,
    /// so a selection can never strand the display on a missing block (mirrors the old `displayedSession`
    /// guard).
    public var selectedSession: SessionBlock {
      candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : session
    }

    /// The bpm range for a given candidate's `zoneTarget`, resolved from the full `zones` map (DECISIONS
    /// #4) — `nil` when the block has no `zoneTarget` or `zones` is `nil`. 2.2's `Zones` exposes named
    /// `z1…z5` fields (no `subscript(Zone)`), so the lookup is an exhaustive switch.
    public func zoneRange(for block: SessionBlock) -> ZoneRange? {
      guard let zone = block.zoneTarget, let zones else { return nil }
      switch zone {
      case .z1: return zones.z1
      case .z2: return zones.z2
      case .z3: return zones.z3
      case .z4: return zones.z4
      case .z5: return zones.z5
      }
    }
  }

  /// What the feature tells its parent: the athlete asked to **skip** today's session (the parent owns what
  /// happens next — permission, not dismiss, PRD §7.4.3), or **committed a selection** (`selectionChanged`)
  /// which the parent persists by value (DECISIONS D4/D5).
  public enum Delegate: Equatable {
    case skipRequested
    case selectionChanged(SessionBlock)
  }

  public enum Action: Equatable {
    /// Tap a candidate card to **commit** it as today's pick. Selects an in-range index and emits
    /// `.delegate(.selectionChanged(block))`; re-selecting the already-committed index and out-of-range are
    /// both no-ops (no state change, no delegate). Display-only — no server re-roll (DECISIONS #1).
    case cardSelected(index: Int)
    /// The warm "skipping is fine today" affordance — emits the upward delegate, mutates no session state.
    case skipTapped
    /// Parent-observed; the reducer returns `.none` for it.
    case delegate(Delegate)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .cardSelected(index):
        // Tap-to-commit (DECISIONS D1): select an unselected in-range index and tell the parent to persist
        // it. Re-selecting the committed index and out-of-range are no-ops — there is no tap-again-revert.
        guard state.candidates.indices.contains(index), index != state.selectedIndex else { return .none }
        state.selectedIndex = index
        return .send(.delegate(.selectionChanged(state.candidates[index])))

      case .skipTapped:
        // Permission, not dismiss (PRD §7.4.3): emit the upward delegate, mutate no session/selection
        // state. The parent owns what happens next; the card is never hidden here.
        return .send(.delegate(.skipRequested))

      case .delegate:
        // Parent-observed — no state mutation (included so the `switch` is exhaustive).
        return .none
      }
    }
  }
}
