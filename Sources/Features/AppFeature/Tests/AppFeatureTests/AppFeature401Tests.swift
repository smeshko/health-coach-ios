import APIClient
import ComposableArchitecture
import XCTest

@testable import AppFeature

/// Exhaustive `TestStore` tests for the global 401 path (ARCHITECTURE §13 / D12 / D13, PRD §8.4). Each
/// test injects a test-controlled `AsyncStream<SessionEvent>` (overriding `apiClient.sessionEvents`) so
/// delivery is deterministic. The exhaustive store fails on any unexpected effect — so "no retry / no
/// re-subscribe storm" is asserted simply by the absence of unexpected actions.
@MainActor
final class AppFeature401Tests: XCTestCase {
  private var tokenInvalid: AppFeature.State {
    .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
  }

  func test_appWillAppear_unauthorized_swapsToConnectTokenInvalid() async {
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

  func test_unauthorized_thenConnect_doesNotResubscribe() async {
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

  func test_unauthorized_twice_reappliesSwap_noRetry() async {
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

    // A second 401 on the still-live stream re-applies the same swap and emits only `.cancel(.appWork)`
    // — no new subscription, no retry (exhaustive store catches any extra effect).
    continuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized)

    continuation.finish()
    await store.finish()
  }

  func test_validation_401SwapsToOnboarding() async {
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

    XCTAssertNotNil(store.state.onboarding)

    continuation.finish()
    await store.finish()
  }
}
