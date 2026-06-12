import ComposableArchitecture
import OnboardingFeature
import SettingsFeature
import Testing

@testable import AppFeature

/// Exhaustive `TestStore` tests (ARCHITECTURE D18) for the Phase 7.1 shell: the enum-state
/// `.onboarding ↔ .main` switch and the per-tab `StackState` independence. The 401 routing effect is
/// covered separately in `AppFeature401Tests` (TASK-002).
@MainActor
struct AppFeatureSwitchTests {
  @Test func test_startsInMain() {
    // Happy-path-first (personal app): the app defaults to `.main`; the launch token check swaps to
    // onboarding only when no token is stored (covered in `test_restoreSession_*`).
    #expect(AppFeature.State() == .main(MainTabs.State()))
  }

  @Test func test_restoreSession_noStoredToken_swapsToOnboarding() async {
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test func test_restoreSession_emptyToken_swapsToOnboarding() async {
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { "" }
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test func test_restoreSession_storedToken_staysInMain() async {
    // The happy path: a token exists → the default `.main` is kept, no state change.
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { "stored-bearer-token" }
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, true)
  }

  @Test func test_connectedDelegate_swapsToMain() async {
    let store = TestStore(initialState: AppFeature.State.onboarding(OnboardingFeature.State())) {
      AppFeature()
    }

    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
    }
  }

  @Test func test_mainTokenResetDelegate_swapsToOnboarding() async {
    // The AppFeature seam (AC3): a `tokenReset` delegate bubbled up from the You tab swaps `.main →
    // .onboarding` so the connect flow can be re-run without relaunch.
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    }

    await store.send(.main(.delegate(.tokenReset))) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test func test_settingsTokenReset_bubblesThroughMainTabs_toOnboarding() async {
    // Full route: the You-tab root's `tokenReset` delegate bubbles through `MainTabs` (which re-emits
    // its own `.delegate(.tokenReset)`) up to `AppFeature`, which swaps to onboarding.
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    }

    await store.send(.main(.settingsRoot(.delegate(.tokenReset))))
    await store.receive(\.main.delegate, .tokenReset) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test func test_tabSelected_updatesSelectedTab() async {
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    }

    var expected = MainTabs.State()
    expected.selectedTab = .weekly
    await store.send(.main(.tabSelected(.weekly))) {
      $0 = .main(expected)
    }
  }

  @Test func test_perTabStacks_startEmpty() async {
    // The Week / You drill-down stacks are caseless until Epics 9/10 add pushable destinations; the
    // named slots exist and start empty. Stack-independence under pushes returns with those cases.
    let mainState = MainTabs.State()
    #expect(mainState.weekly.count == 0)
    #expect(mainState.settings.count == 0)
  }
}
