import APIClient
import ComposableArchitecture
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
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
    }

    // Start the subscription, then deliver a 401.
    await store.send(._appWillAppear)
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }
    // The 401 handler emits only `.cancel(.appWork)` (silent) — the exhaustive store would fail here on
    // any retry / network / re-subscribe effect.

    continuation.finish()
    await store.finish()
  }

  @Test func test_unauthorized_thenConnect_doesNotResubscribe() async {
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
    }

    await store.send(._appWillAppear)

    // First 401 → swap to onboarding/connect.
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }

    // User reconnects → back to main. The reducer never self-sends `._appWillAppear`, so no new
    // subscription is opened (the view's once-mounted hook is not re-fired by the TestStore).
    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
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

  @Test func test_unauthorized_whenAlreadyOnboarding_isNoOp() async {
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
    }

    await store.send(._appWillAppear)

    // First 401 from `.main` → swap to onboarding/connect.
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }

    // A second 401 — now delivered while already `.onboarding` — is a NO-OP under the `.main`-only
    // guard: no state change (the `receive` carries no mutation closure), no `.cancel(.appWork)`, no
    // re-subscribe (the exhaustive store would catch any extra effect).
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized)

    continuation.finish()
    await store.finish()
  }

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

  @Test func test_validation_401SwapsToOnboarding() async {
    // The epic's literal validation case: a TestStore emits a 401 session event → state swaps to
    // onboarding.
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
    }

    await store.send(._appWillAppear)
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0 = self.tokenInvalid
    }

    #expect(store.state.onboarding != nil)

    continuation.finish()
    await store.finish()
  }
}
