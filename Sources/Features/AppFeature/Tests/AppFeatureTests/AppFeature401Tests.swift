import APIClient
import CoachCore
import ComposableArchitecture
import Foundation
import LogClient
import OnboardingFeature
import Testing

@testable import AppFeature

/// Exhaustive `TestStore` tests for the global 401 path (ARCHITECTURE §13 / D12 / D13, PRD §8.4). Each
/// test injects a test-controlled `AsyncStream<SessionEvent>` (overriding `apiClient.sessionEvents`) so
/// delivery is deterministic. The exhaustive store fails on any unexpected effect — so "no retry / no
/// re-subscribe storm" is asserted simply by the absence of unexpected actions.
@MainActor
struct AppFeature401Tests {
  private var tokenInvalid: AppFeature.State {
    .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
  }

  @Test func test_appWillAppear_unauthorized_swapsToConnectTokenInvalid() async {
    // Folds the former AppFeatureLogTests.test_appWillAppear_emitsLifecycleLog (audit MERGE): the
    // `.lifecycle` "App will appear" line is asserted here on the same `._appWillAppear` walk.
    let recorder = LogRecorder()
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
      $0.log = .recording(into: recorder)
    }

    // Start the subscription, then deliver a 401.
    await store.send(._appWillAppear)
    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("App will appear") })
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }
    // The 401 handler returns `.none` (just the `.main → .onboarding` swap, whose `ifCaseLet` tears
    // down child effects) — the exhaustive store would fail here on any retry / network / re-subscribe
    // effect.

    continuation.finish()
    await store.finish()
  }

  @Test func test_unauthorized_thenConnect_doesNotResubscribe() async {
    let now = Date(timeIntervalSince1970: 0)
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // the post-connect Today open lands at the gate
      $0.apiClient.sessionEvents = { stream }
    }

    await store.send(._appWillAppear)

    // First 401 → swap to onboarding/connect.
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }

    // User reconnects → back to main. The reducer never self-sends `._appWillAppear`, so no new
    // subscription is opened (the view's once-mounted hook is not re-fired by the TestStore). The connect
    // swap also dispatches the Today cache-first open (D8), which lands at the check-in gate here.
    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
    }
    await store.receive(\.main.todayRoot.onAppOpen)
    await store.receive(\.main.todayRoot._checkInRequired) {
      var main = MainTabs.State()
      main.todayRoot.briefState = .checkInRequired
      $0 = .main(main)
    }

    // Proof the ORIGINAL subscription survived the swap-back: a second 401 on the same stream is still
    // delivered (no teardown / re-subscribe was needed).
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }

    continuation.finish()
    await store.finish()
  }

  // Note: the former test_unauthorized_whenAlreadyOnboarding_isNoOp folded into the test below (audit
  // MERGE) — both exercise the `guard case .main` no-op while `.onboarding`; this one asserts the
  // stronger property (typed token + reason preserved across the no-op 401).
  @Test func test_unauthorized_whileOnboarding_preservesTypedToken() async {
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    var onboarding = OnboardingFeature.State(step: .connect(reason: nil))
    onboarding.connect.token = "typed-token-123"
    let store = TestStore(initialState: AppFeature.State.onboarding(onboarding)) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
    }

    await store.send(._appWillAppear)

    // A 401 arriving during an active connect attempt must NOT reconstruct onboarding state: the typed
    // token + the (nil) reason are preserved (no banner flash, no field wipe) — the Connect screen owns
    // its inline error. No mutation closure ⇒ the exhaustive store asserts the state is unchanged.
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized)

    #expect(store.state.onboarding?.connect.token == "typed-token-123")
    #expect(store.state.onboarding?.step == .connect(reason: nil))

    continuation.finish()
    await store.finish()
  }
}
