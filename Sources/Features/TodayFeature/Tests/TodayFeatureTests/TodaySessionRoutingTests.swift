import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// The parent `ready`-content routing (Phase 8.3, TASK-005): given a loaded `.ready(brief)`, the content
/// mode the view switches on is `TodaySessionMode.from(brief)` — `.forcedRest` for a tripped gate and
/// `.normal` for an untripped (coach-easy) day. This asserts the **routing decision** at the parent
/// `briefState` seam (the visual difference is the TASK-004 contrast snapshot); a coach-easy day is never
/// routed to the forced-REST branch.
@MainActor
struct TodaySessionRoutingTests {
  private func brief(_ scenario: SampleScenario) throws -> DomainModels.DailyBrief {
    try SampleData.dailyBrief(scenario).domain
  }

  /// Extract the loaded brief from a `.ready` state exactly as the view's `case let .ready(brief, _)` does.
  private func loadedBrief(_ state: TodayFeature.State) -> DomainModels.DailyBrief? {
    guard case let .ready(brief, _) = state.briefState else { return nil }
    return brief
  }

  @Test func test_readyForcedRestBrief_routesToForcedRest() throws {
    let brief = try brief(.dailyBriefRestGIFlare)
    let state = TodayFeature.State(briefState: .ready(brief, .fresh))
    let loaded = try #require(loadedBrief(state))
    #expect(TodaySessionMode.from(loaded) == .forcedRest(gate: brief.safetyGate, override: brief.session))
  }

  @Test func test_readyCoachEasyBrief_routesToNormal() throws {
    let brief = try brief(.dailyBriefAmber)
    let state = TodayFeature.State(briefState: .ready(brief, .fresh))
    let loaded = try #require(loadedBrief(state))
    // An untripped (coach-easy) day must NOT route to the forced-REST branch.
    #expect(TodaySessionMode.from(loaded) == .normal(brief.session))
  }
}
