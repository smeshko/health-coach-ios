import ComposableArchitecture
import DomainModels

/// The shared **daily session** feature (ARCHITECTURE §4.5 / D5 — the promoted hybrid component in its own
/// target) — a `@Reducer` rendering the daily `SessionBlock` through the `DesignSystem` `SessionCard`, with
/// the 2026-06-10 inline-swap interaction (SWAP TO / SWAPPED TO, tap-again-to-revert) and the warm
/// permission-to-skip affordance.
///
/// **Parent-supplied input, no repository.** Every field of `State` is handed in by the parent
/// (`TodayFeature`): the primary `session`, its `alternatives`, the `skipOk` flag, the `.session`-typed
/// `narrative` slice, and the full `Zones` map. The feature reaches **no** repository, data-source client,
/// `WireModels`, GRDB, or HealthKit (§3/§4.5) — it imports only `ComposableArchitecture` + `DomainModels`
/// (the view adds `SwiftUI` + `DesignSystem`). Swap is **display-only**: picking an alternative changes
/// which already-supplied block renders, with no network/server re-roll (PRD §7.4.3, DECISIONS #1).
///
/// **Daily-only.** The 2026-06-10 design iteration makes the weekly rows a distinct compact presentation,
/// so Weekly renders a pure `WeeklySessionRow` (Phase 9.2) and never embeds this feature — there is no
/// `.weekly` input or initializer here or later.
@Reducer
public struct SessionFeature {
  @ObservableState
  public struct State: Equatable {
    /// The **primary** (server-recommended) daily session — never lost (revert returns to it).
    public var session: SessionBlock
    /// The ≤2 validated substitutes from the brief (may be empty — forced-REST or none offered).
    public var alternatives: [SessionBlock]
    /// Whether to surface the warm "skipping is fine today" affordance.
    public var skipOk: Bool
    /// The `type == .session` narrative slice (pre-filtered by the parent, DECISIONS #3); rendered
    /// **inside** the card's narrative slot per the 2026-06-10 iteration.
    public var narrative: [NarrativeSection]
    /// The **full** five-zone bpm map (`ProfileRepository.zones()` returns the whole map, not a single
    /// range), passed in by the parent so `displayedZoneRange` resolves a *swapped* alternative's zone
    /// correctly (DECISIONS #4). The feature never resolves zones itself (§3/D19).
    public var zones: Zones?
    /// **Local UI** swap selection by **index** into `alternatives` (2.2's `SessionBlock` carries no
    /// stable `ID`; DECISIONS #2). `nil` ⇒ the primary `session` is shown.
    public var selectedAlternativeIndex: Int?
    /// **Local UI** state for the inline SWAP TO list. Independent of the selection: collapsing the list
    /// keeps a swapped selection (PLAN inline decision).
    public var isSwapExpanded: Bool

    public init(
      session: SessionBlock,
      alternatives: [SessionBlock] = [],
      skipOk: Bool = false,
      narrative: [NarrativeSection] = [],
      zones: Zones? = nil,
      selectedAlternativeIndex: Int? = nil,
      isSwapExpanded: Bool = false
    ) {
      self.session = session
      self.alternatives = alternatives
      self.skipOk = skipOk
      self.narrative = narrative
      self.zones = zones
      self.selectedAlternativeIndex = selectedAlternativeIndex
      self.isSwapExpanded = isSwapExpanded
    }

    /// The session the card actually renders — the selected in-range alternative, else the primary. A
    /// stale/out-of-range index (e.g. after a refreshed brief re-supplies a shorter `alternatives`) falls
    /// back to the primary, so a swap can never strand the display on a missing block.
    public var displayedSession: SessionBlock {
      if let index = selectedAlternativeIndex, alternatives.indices.contains(index) {
        return alternatives[index]
      }
      return session
    }

    /// The bpm range for the **displayed** session's `zoneTarget`, resolved from the full `zones` map
    /// (DECISIONS #4) — `nil` when the displayed session has no `zoneTarget` or `zones` is `nil`. 2.2's
    /// `Zones` exposes named `z1…z5` fields (no `subscript(Zone)`), so the lookup is an exhaustive switch.
    public var displayedZoneRange: ZoneRange? {
      guard let zone = displayedSession.zoneTarget, let zones else { return nil }
      switch zone {
      case .z1: return zones.z1
      case .z2: return zones.z2
      case .z3: return zones.z3
      case .z4: return zones.z4
      case .z5: return zones.z5
      }
    }
  }

  /// The single thing the feature tells its parent: the athlete asked to skip today's session. The parent
  /// (`TodayFeature`) owns what happens next (UI ack / analytics) — this feature never hides the card
  /// (permission, not dismiss — PRD §7.4.3).
  public enum Delegate: Equatable {
    case skipRequested
  }

  public enum Action: Equatable {
    /// Expand/collapse the inline SWAP TO list (local display state).
    case swapToggled
    /// Tap an alternatives row — **toggle semantics**: selects an unselected in-range index; tapping the
    /// currently-selected index reverts to the recommended session (the design's tap-again-to-revert);
    /// out-of-range is a no-op. Display-only — no repository/server call (DECISIONS #1/#2).
    case alternativeTapped(index: Int)
    /// The warm "skipping is fine today" affordance — emits the upward delegate, mutates no session state.
    case skipTapped
    /// Parent-observed; the reducer returns `.none` for it.
    case delegate(Delegate)
  }

  public init() {}

  // The reducer body is added in TASK-002 (the swap/select/skip logic). An `EmptyReducer` keeps the
  // scaffold compiling for TASK-001 (the State + `displayedSession`/`displayedZoneRange` derivations).
  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
