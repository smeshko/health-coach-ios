import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `SessionFeature` — the inline swap expand/collapse
/// (`swapToggled`), the **toggle-semantics** alternative selection (`alternativeTapped`: select /
/// tap-again-to-revert / out-of-range no-op), the independence of expansion and selection, the `skipTapped`
/// delegate, and the empty-alternatives / stale-selection guards. Swap is **display-only** — no arm emits a
/// repository/server effect (the only effect is the skip delegate).
///
/// Fixtures are **inline `DomainModels` literals**: the `SampleData` briefs carry ≤1 alternative and no
/// different-zone alternative, so they cannot drive the swap cases (the `displayedZoneRange` assertion needs
/// an alternative whose `zoneTarget` differs from the primary's).
@MainActor
struct SessionFeatureTests {
  // MARK: - Fixtures

  /// The primary recommended session — an easy Z2 run with a bpm/cadence line and an `effort_based` flag.
  private func primary() -> SessionBlock {
    SessionBlock(
      card: .easyRun, intensity: .easy, zoneTarget: .z2,
      durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.effortBased]
    )
  }

  /// First alternative — a lower-impact steady-cardio block in a **different** zone (Z1) than the primary,
  /// so a swap to it must re-resolve `displayedZoneRange` to Z1 (DECISIONS #4).
  private func altLowImpact() -> SessionBlock {
    SessionBlock(
      card: .steadyCardio, intensity: .easy, zoneTarget: .z1,
      durationMinLow: 40, durationMinHigh: 40, flags: [.lowImpact]
    )
  }

  /// Second alternative — a no-zone strength block (renders the effort scale, not a zone bar).
  private func altStrength() -> SessionBlock {
    SessionBlock(card: .strengthFull, intensity: .quality, durationMinLow: 30, durationMinHigh: 30)
  }

  /// A full five-zone bpm map so `displayedZoneRange` has a range to resolve per zone.
  private func zones() -> Zones {
    Zones(
      z1: ZoneRange(low: 90, high: 110),
      z2: ZoneRange(low: 110, high: 130),
      z3: ZoneRange(low: 130, high: 150),
      z4: ZoneRange(low: 150, high: 170),
      z5: ZoneRange(low: 170, high: 190)
    )
  }

  /// A store seeded with the primary + both alternatives + the zone map (the swap-capable scenario).
  private func swapStore() -> TestStore<SessionFeature.State, SessionFeature.Action> {
    TestStore(
      initialState: SessionFeature.State(
        session: primary(), alternatives: [altLowImpact(), altStrength()], zones: zones()
      )
    ) { SessionFeature() }
  }

  // MARK: - swapToggled

  @Test func test_swapToggled_expandsAndCollapses() async {
    let store = swapStore()
    await store.send(.swapToggled) { $0.isSwapExpanded = true }
    await store.send(.swapToggled) { $0.isSwapExpanded = false }
  }

  // MARK: - alternativeTapped (select / revert / out-of-range)

  @Test func test_alternativeTapped_selects_displayOnly() async {
    let store = swapStore()
    await store.send(.alternativeTapped(index: 0)) { $0.selectedAlternativeIndex = 0 }
    // The card now shows the alternative, and its zone (Z1) — not the primary's (Z2) — resolves (DECISIONS #4).
    #expect(store.state.displayedSession == altLowImpact())
    #expect(store.state.displayedZoneRange == ZoneRange(low: 90, high: 110))
  }

  @Test func test_alternativeTapped_selected_revertsToPrimary() async {
    let store = swapStore()
    await store.send(.alternativeTapped(index: 0)) { $0.selectedAlternativeIndex = 0 }
    // Tapping the SAME (selected) index again reverts to the recommended session — tap-again-to-revert.
    await store.send(.alternativeTapped(index: 0)) { $0.selectedAlternativeIndex = nil }
    #expect(store.state.displayedSession == primary())
    #expect(store.state.displayedZoneRange == ZoneRange(low: 110, high: 130))
  }

  @Test func test_alternativeTapped_switchesSelection() async {
    let store = swapStore()
    await store.send(.alternativeTapped(index: 0)) { $0.selectedAlternativeIndex = 0 }
    // Tapping a DIFFERENT in-range index moves the selection (no revert).
    await store.send(.alternativeTapped(index: 1)) { $0.selectedAlternativeIndex = 1 }
    #expect(store.state.displayedSession == altStrength())
  }

  @Test func test_alternativeTapped_outOfRange_isNoOp() async {
    let store = swapStore()
    // Out-of-range index: no mutation (no trailing closure), no crash.
    await store.send(.alternativeTapped(index: 99))
    // A negative index is equally out-of-range — `Array.indices.contains` rejects it, no crash, no mutation.
    await store.send(.alternativeTapped(index: -1))
    #expect(store.state.selectedAlternativeIndex == nil)
  }

  // MARK: - Expansion / selection independence

  @Test func test_collapse_keepsSelection() async {
    let store = swapStore()
    await store.send(.swapToggled) { $0.isSwapExpanded = true }
    await store.send(.alternativeTapped(index: 0)) { $0.selectedAlternativeIndex = 0 }
    // Collapsing the list must NOT clear the swap — expansion and selection are independent.
    await store.send(.swapToggled) { $0.isSwapExpanded = false }
    #expect(store.state.selectedAlternativeIndex == 0)
    #expect(store.state.displayedSession == altLowImpact())
  }

  // MARK: - skipTapped

  @Test func test_skipTapped_emitsDelegate_noMutation() async {
    let store = swapStore()
    await store.send(.skipTapped)
    await store.receive(.delegate(.skipRequested))
    // No session/selection state changed (the send/receive carry no trailing closures).
    #expect(store.state.selectedAlternativeIndex == nil)
  }

  // MARK: - Empty alternatives / stale selection

  @Test func test_emptyAlternatives_tapHasNoEffect() async {
    let store = TestStore(initialState: SessionFeature.State(session: primary())) { SessionFeature() }
    // With no alternatives, any tap is out-of-range → the primary stays displayed.
    await store.send(.alternativeTapped(index: 0))
    #expect(store.state.displayedSession == primary())
  }

  /// A swap selection that survives a refreshed brief whose `alternatives` no longer contains the index
  /// falls back to the primary at the `displayedSession` level (the refresh-reset risk, computed-property).
  @Test func test_staleSelection_fallsBackToPrimary() {
    let state = SessionFeature.State(
      session: primary(), alternatives: [altLowImpact()], zones: zones(), selectedAlternativeIndex: 1
    )
    #expect(state.displayedSession == primary())
    // The range resolves the PRIMARY's zone (Z2), confirming the fallback feeds zone resolution too.
    #expect(state.displayedZoneRange == ZoneRange(low: 110, high: 130))
  }

  /// No zone target (a strength block) yields no resolved range even with a full zone map.
  @Test func test_displayedZoneRange_nilWhenNoZoneTarget() {
    let state = SessionFeature.State(session: altStrength(), zones: zones())
    #expect(state.displayedZoneRange == nil)
  }
}
