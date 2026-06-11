import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `ReadinessComponent` — the "why" expand/collapse
/// toggle (reducer state, DECISIONS #1) and the `penaltyRows` derivation (each `factor` →
/// `PenaltyFactor.label` via the 5.1 boundary, with the server's positive `points`, in received order).
/// Readiness is physiological-only (PRD §7.4.1): the state carries only `Readiness` — there is no
/// check-in field to assert because none is reachable.
@MainActor
struct ReadinessComponentTests {
  /// The mapped readiness for a canned daily-brief scenario (force-try: an in-bundle fixture decode
  /// failure is a build-time authoring error).
  private func readiness(_ scenario: SampleScenario) throws -> DomainModels.Readiness {
    try SampleData.dailyBrief(scenario).domain.readiness
  }

  @Test func test_whyTapped_togglesExpanded() async throws {
    let amber = try readiness(.dailyBriefAmber)
    let store = TestStore(initialState: ReadinessComponent.State(readiness: amber)) {
      ReadinessComponent()
    }
    await store.send(.whyTapped) { $0.isWhyExpanded = true }
    await store.send(.whyTapped) { $0.isWhyExpanded = false }
  }

  /// The amber fixture's penalties (`sleep_below_7h` 10, `hrv_below_baseline` 8) map to their 5.1 labels
  /// with the server's **positive** points, in received order (no reorder/filter — principle #4).
  @Test func test_penaltyRows_mapLabelsAndPoints_inOrder() throws {
    let rows = ReadinessComponent.State(readiness: try readiness(.dailyBriefAmber)).penaltyRows
    #expect(rows == [
      ReadinessComponent.PenaltyRow(label: "Short sleep", points: 10),
      ReadinessComponent.PenaltyRow(label: "HRV below baseline", points: 8),
    ])
  }

  /// The red fixture exercises a three-penalty list (order + labels preserved).
  @Test func test_penaltyRows_red_threeFactors() throws {
    let rows = ReadinessComponent.State(readiness: try readiness(.dailyBriefRed)).penaltyRows
    #expect(rows == [
      ReadinessComponent.PenaltyRow(label: "Very short sleep", points: 20),
      ReadinessComponent.PenaltyRow(label: "Resting HR elevated", points: 15),
      ReadinessComponent.PenaltyRow(label: "Hard session yesterday", points: 10),
    ])
  }

  /// The green fixture has no penalties → no rows (collapsed gauge only).
  @Test func test_penaltyRows_green_empty() throws {
    #expect(try ReadinessComponent.State(readiness: readiness(.dailyBriefGreen)).penaltyRows.isEmpty)
  }

  /// An `.unknown(raw)` factor still yields a graceful human label (never the raw machine key).
  @Test func test_unknownFactor_gracefulLabel_notRawKey() {
    let readiness = DomainModels.Readiness(
      score: 50,
      band: .amber,
      penalties: [DomainModels.ReadinessPenalty(factor: .unknown("foo_bar"), points: 5)]
    )
    let rows = ReadinessComponent.State(readiness: readiness).penaltyRows
    #expect(rows == [ReadinessComponent.PenaltyRow(label: "Foo Bar", points: 5)])
    #expect(rows.first?.label != "foo_bar")
  }
}
