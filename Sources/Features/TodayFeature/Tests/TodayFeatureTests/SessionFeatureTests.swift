import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `SessionFeature` — the carousel **tap-to-commit**
/// selection (`cardSelected`: select an in-range candidate / re-select-is-no-op / out-of-range no-op), the
/// `selectionChanged` + `skipRequested` delegates, the default primary pre-selection, and the
/// `selectedSession` / `zoneRange(for:)` projections. Selection is **display-only** here — the only effects
/// are the upward delegates; the parent owns persistence (DECISIONS D5).
///
/// Fixtures are **inline `DomainModels` literals**: the `SampleData` briefs carry ≤1 alternative and no
/// different-zone alternative, so they cannot drive the selection cases (the `zoneRange(for:)` assertion
/// needs a candidate whose `zoneTarget` differs from the primary's).
@MainActor
struct SessionFeatureTests {
  // MARK: - Fixtures

  /// The primary recommended session (candidate 0) — an easy Z2 run with a bpm/cadence line.
  private func primary() -> SessionBlock {
    SessionBlock(
      card: .easyRun, intensity: .easy, zoneTarget: .z2,
      durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.effortBased]
    )
  }

  /// First alternative (candidate 1) — a lower-impact steady-cardio block in a **different** zone (Z1) than
  /// the primary, so selecting it must re-resolve `zoneRange(for:)` to Z1 (DECISIONS #4).
  private func altLowImpact() -> SessionBlock {
    SessionBlock(
      card: .steadyCardio, intensity: .easy, zoneTarget: .z1,
      durationMinLow: 40, durationMinHigh: 40, flags: [.lowImpact]
    )
  }

  /// Second alternative (candidate 2) — a no-zone strength block (renders the effort scale, not a zone bar).
  private func altStrength() -> SessionBlock {
    SessionBlock(card: .strengthFull, intensity: .quality, durationMinLow: 30, durationMinHigh: 30)
  }

  /// A full five-zone bpm map so `zoneRange(for:)` has a range to resolve per zone.
  private func zones() -> Zones {
    Zones(
      z1: ZoneRange(low: 90, high: 110),
      z2: ZoneRange(low: 110, high: 130),
      z3: ZoneRange(low: 130, high: 150),
      z4: ZoneRange(low: 150, high: 170),
      z5: ZoneRange(low: 170, high: 190)
    )
  }

  /// A store seeded with the primary + both alternatives + the zone map (the carousel scenario). Candidates
  /// are `[primary, altLowImpact, altStrength]` at indices 0/1/2.
  private func carouselStore() -> TestStore<SessionFeature.State, SessionFeature.Action> {
    TestStore(
      initialState: SessionFeature.State(
        session: primary(), alternatives: [altLowImpact(), altStrength()], zones: zones()
      )
    ) { SessionFeature() }
  }

  // MARK: - Default selection

  @Test func test_default_primaryPreSelected() {
    let state = SessionFeature.State(session: primary(), alternatives: [altLowImpact()])
    #expect(state.selectedIndex == 0)
    #expect(state.selectedSession == primary())
    #expect(state.candidates == [primary(), altLowImpact()])
  }

  // MARK: - cardSelected (commit / re-select / out-of-range)

  @Test func test_cardSelected_selectsAlternative_emitsDelegate() async {
    let store = carouselStore()
    await store.send(.cardSelected(index: 1)) { $0.selectedIndex = 1 }
    await store.receive(.delegate(.selectionChanged(altLowImpact())))
    // The card now shows the alternative, and its zone (Z1) — not the primary's (Z2) — resolves (DECISIONS #4).
    #expect(store.state.selectedSession == altLowImpact())
    #expect(store.state.zoneRange(for: store.state.selectedSession) == ZoneRange(low: 90, high: 110))
  }

  @Test func test_cardSelected_switchesSelection() async {
    let store = carouselStore()
    await store.send(.cardSelected(index: 1)) { $0.selectedIndex = 1 }
    await store.receive(.delegate(.selectionChanged(altLowImpact())))
    // Tapping a DIFFERENT in-range index moves the selection and re-emits the delegate.
    await store.send(.cardSelected(index: 2)) { $0.selectedIndex = 2 }
    await store.receive(.delegate(.selectionChanged(altStrength())))
    #expect(store.state.selectedSession == altStrength())
  }

  @Test func test_cardSelected_backToPrimary_emitsDelegate() async {
    let store = carouselStore()
    await store.send(.cardSelected(index: 2)) { $0.selectedIndex = 2 }
    await store.receive(.delegate(.selectionChanged(altStrength())))
    // Selecting candidate 0 (the primary) is an ordinary commit — it emits the delegate with the primary.
    await store.send(.cardSelected(index: 0)) { $0.selectedIndex = 0 }
    await store.receive(.delegate(.selectionChanged(primary())))
    #expect(store.state.selectedSession == primary())
  }

  @Test func test_cardSelected_sameIndex_isNoOp() async {
    let store = carouselStore()
    // Re-selecting the already-committed index (default 0) does nothing — no tap-again-revert, no delegate.
    await store.send(.cardSelected(index: 0))
    #expect(store.state.selectedIndex == 0)
  }

  @Test func test_cardSelected_outOfRange_isNoOp() async {
    let store = carouselStore()
    // Out-of-range index: no mutation (no trailing closure), no delegate, no crash.
    await store.send(.cardSelected(index: 99))
    // A negative index is equally out-of-range — `Array.indices.contains` rejects it, no crash, no mutation.
    await store.send(.cardSelected(index: -1))
    #expect(store.state.selectedIndex == 0)
  }

  // MARK: - skipTapped

  @Test func test_skipTapped_emitsDelegate_noMutation() async {
    let store = carouselStore()
    await store.send(.skipTapped)
    await store.receive(.delegate(.skipRequested))
    // No session/selection state changed (the send/receive carry no trailing closures).
    #expect(store.state.selectedIndex == 0)
  }

  // MARK: - Projections / stale-selection guard

  @Test func test_emptyAlternatives_tapHasNoEffect() async {
    let store = TestStore(initialState: SessionFeature.State(session: primary())) { SessionFeature() }
    // With only the primary, the sole in-range index is 0 (already selected) — any other tap is out-of-range.
    await store.send(.cardSelected(index: 1))
    #expect(store.state.selectedSession == primary())
  }

  /// A selection that survives a refreshed brief whose `candidates` no longer contains the index falls back
  /// to the primary at the `selectedSession` level (the refresh-reset risk, computed-property).
  @Test func test_staleSelection_fallsBackToPrimary() {
    let state = SessionFeature.State(
      session: primary(), alternatives: [altLowImpact()], zones: zones(), selectedIndex: 5
    )
    #expect(state.selectedSession == primary())
    // The range resolves the PRIMARY's zone (Z2), confirming the fallback feeds zone resolution too.
    #expect(state.zoneRange(for: state.selectedSession) == ZoneRange(low: 110, high: 130))
  }

  /// No zone target (a strength block) yields no resolved range even with a full zone map.
  @Test func test_zoneRange_nilWhenNoZoneTarget() {
    let state = SessionFeature.State(session: primary(), zones: zones())
    #expect(state.zoneRange(for: altStrength()) == nil)
  }
}
