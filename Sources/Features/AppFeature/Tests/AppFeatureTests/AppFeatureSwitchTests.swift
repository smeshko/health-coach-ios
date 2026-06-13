import ComposableArchitecture
import LogClient
import OnboardingFeature
import SettingsFeature
import Testing

@testable import AppFeature

/// Exhaustive `TestStore` tests (ARCHITECTURE D18) for the Phase 7.1 shell: the enum-state
/// `.onboarding ↔ .main` switch and the per-tab `StackState` independence. The 401 routing effect is
/// covered separately in `AppFeature401Tests` (TASK-002).
@MainActor
struct AppFeatureSwitchTests {
  /// The app defaults to `.main` (the session-restore design: start in `.main`, the background token
  /// check swaps to onboarding only when no token is stored — a returning user lands straight on the
  /// app). If this default flips, a stored-token launch would wrongly stick on Connect (review #2.2).
  @Test func test_defaultState_isMain() {
    #expect(AppFeature.State() == .main(MainTabs.State()))
  }

  /// A nil OR empty stored token both fall back to onboarding (parameterized — the two cases share the
  /// `._tokenChecked(false)` receive path). Folds the former AppFeatureLogTests.test_restoreSession_*
  /// log asserts (audit MERGE): the `.lifecycle` "Restoring session" + `.app` onboarding-fallback lines
  /// are asserted here on the same `._restoreSession` walk.
  @Test(arguments: [String?.none, ""])
  func test_restoreSession_missingToken_swapsToOnboarding(token: String?) async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { token }
      $0.log = .recording(into: recorder)
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      $0 = .onboarding(OnboardingFeature.State())
    }

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("Restoring session") })
    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("falling back to onboarding") })
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
    // Folds the former AppFeatureLogTests.test_connected_emitsAppLog (audit MERGE): the `.app`
    // "Connected" line is asserted here on the same connected-swap walk.
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.onboarding(OnboardingFeature.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Connected") })
  }

  @Test func test_settingsTokenReset_bubblesThroughMainTabs_toOnboarding() async {
    // Full route: the You-tab root's `tokenReset` delegate bubbles through `MainTabs` (which re-emits
    // its own `.delegate(.tokenReset)`) up to `AppFeature`, which swaps to onboarding. (The former
    // test_mainTokenResetDelegate_swapsToOnboarding folded here — audit MERGE — this full bubble is the
    // strictly-stronger walk.) Also folds AppFeatureLogTests.test_tokenReset_emitsAppLog: the `.app`
    // "Token reset" line is asserted on this same delegate walk.
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    await store.send(.main(.settingsRoot(.delegate(.tokenReset))))
    await store.receive(\.main.delegate, .tokenReset) {
      $0 = .onboarding(OnboardingFeature.State())
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Token reset") })
  }

  @Test func test_perTabStacks_startEmpty() async {
    // The Week / You drill-down stacks are caseless until Epics 9/10 add pushable destinations; the
    // named slots exist and start empty. Stack-independence under pushes returns with those cases.
    let mainState = MainTabs.State()
    #expect(mainState.weekly.count == 0)
    #expect(mainState.settings.count == 0)
  }
}
