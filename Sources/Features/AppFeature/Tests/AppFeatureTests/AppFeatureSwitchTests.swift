import ComposableArchitecture
import XCTest

@testable import AppFeature

/// Exhaustive `TestStore` tests (ARCHITECTURE D18) for the Phase 7.1 shell: the enum-state
/// `.onboarding ↔ .main` switch and the per-tab `StackState` independence. The 401 routing effect is
/// covered separately in `AppFeature401Tests` (TASK-002).
@MainActor
final class AppFeatureSwitchTests: XCTestCase {
  func test_startsInOnboarding() {
    XCTAssertEqual(AppFeature.State(), .onboarding(OnboardingFeature.State()))
  }

  func test_connectedDelegate_swapsToMain() async {
    let store = TestStore(initialState: AppFeature.State.onboarding(OnboardingFeature.State())) {
      AppFeature()
    }

    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
    }
  }

  func test_tabSelected_updatesSelectedTab() async {
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    }

    var expected = MainTabs.State()
    expected.selectedTab = .weekly
    await store.send(.main(.tabSelected(.weekly))) {
      $0 = .main(expected)
    }
  }

  func test_perTabStacks_areIndependent() async {
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    }

    // Pushing onto the Today stack must leave Week / You (settings) empty.
    var expected = MainTabs.State()
    expected.today[id: 0] = .placeholder(PlaceholderFeature.State())
    await store.send(.main(.today(.push(id: 0, state: .placeholder(PlaceholderFeature.State()))))) {
      $0 = .main(expected)
    }

    let mainState = store.state.main
    XCTAssertEqual(mainState?.today.count, 1)
    XCTAssertEqual(mainState?.weekly.count, 0)
    XCTAssertEqual(mainState?.settings.count, 0)
  }
}
