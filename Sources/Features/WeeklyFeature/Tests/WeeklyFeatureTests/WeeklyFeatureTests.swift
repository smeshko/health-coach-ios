import ComposableArchitecture
import Foundation
import Testing

@testable import WeeklyFeature

/// The target/harness smoke test — proves `WeeklyFeature` + the exhaustive `TestStore` wire up. The
/// detection (TASK-002), fetch/orchestration (TASK-003), rhythm + toggles (TASK-004) cases grow this suite.
@MainActor
struct WeeklyFeatureTests {
  @Test func test_initialState_isIdle() {
    let state = WeeklyFeature.State()
    #expect(state.weeklyState == .idle)
  }

  @Test func test_noOpAction_doesNotMutate() async {
    let store = TestStore(initialState: WeeklyFeature.State()) {
      WeeklyFeature()
    }
    // The shell is a no-op until TASK-003's fetch effect — `task` produces no state change, no effect.
    await store.send(.task)
  }
}
