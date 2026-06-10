import ComposableArchitecture
import Testing

@testable import TodayFeature

/// Smoke coverage (ARCHITECTURE D18) proving the `TodayFeature` target + the exhaustive `TestStore`
/// harness wire up: the initial lifecycle is `.idle`, and the pure-UI segmented toggle flips
/// `selectedSection`. The orchestration / check-in / debounce suites land in TASK-002–004.
@MainActor
struct TodayFeatureTests {
  @Test func test_initialState_isIdle_exerciseSelected() async {
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    }
    #expect(store.state.briefState == .idle)
    #expect(store.state.selectedSection == .exercise)
    #expect(store.state.lastSyncedAt == nil)
  }

  @Test func test_sectionSelected_flipsSelectedSection() async {
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    }
    await store.send(.sectionSelected(.nutrition)) { $0.selectedSection = .nutrition }
    await store.send(.sectionSelected(.exercise)) { $0.selectedSection = .exercise }
  }
}
