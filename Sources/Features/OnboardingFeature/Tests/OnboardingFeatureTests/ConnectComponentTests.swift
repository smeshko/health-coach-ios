import APIClient
import ComposableArchitecture
import Testing
import TokenClient

@testable import OnboardingFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `ConnectComponent` — the load-bearing
/// write→probe→clear ordering (DECISIONS 1), the success/failure branches, the binding-reset recovery
/// path, paste, and the `canSubmit` gate. A `CallRecorder` actor records the `TokenClient`/`APIClient`
/// call order so we can assert `write` precedes `probe` and that `clear` runs on failure only.
@MainActor
struct ConnectComponentTests {
  /// Records the order of `write` / `probe` / `clear` across the stubbed dependencies.
  private actor CallRecorder {
    private(set) var calls: [String] = []
    func record(_ name: String) { calls.append(name) }
  }

  @Test func test_connect_validToken_writes_thenProbes_thenEmitsConnected_keepsToken() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "  ahc_live_ok\n")) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = { await recorder.record("clear") }
      $0.apiClient.probe = {
        await recorder.record("probe")
        return true
      }
    }

    await store.send(.connectTapped) { $0.validation = .validating }
    await store.receive(\.probeResponse) { $0.validation = .idle }
    await store.receive(\.delegate, .connected)
    await store.finish()

    let calls = await recorder.calls
    #expect(calls == ["write", "probe"], "write must precede probe; clear must NOT run on success")
  }

  /// A probe failure (any error type — the reducer has a single `.probeResponse(.failure)` arm with no
  /// per-error branch) clears the just-written candidate and shows the inline error. Parameterized over
  /// 401 + transport (folds the former test_connect_transportFailure_… — audit MERGE).
  @Test(arguments: [APIError.unauthorized, APIError.transport("offline")])
  func test_connect_probeFailure_clearsToken_showsError_noConnected(probeError: APIError) async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_bad")) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = { await recorder.record("clear") }
      $0.apiClient.probe = {
        await recorder.record("probe")
        throw probeError
      }
    }

    await store.send(.connectTapped) { $0.validation = .validating }
    await store.receive(\.probeResponse) { $0.validation = .invalid }
    await store.finish()

    let calls = await recorder.calls
    #expect(calls == ["write", "probe", "clear"], "a probe failure must clear the just-written candidate")
    // The absence of a received `.delegate(.connected)` is asserted by the exhaustive store (it would
    // fail on any unexpected action).
  }

  @Test func test_editingToken_afterError_resetsValidationToIdle() async {
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .invalid)) {
      ConnectComponent()
    }

    await store.send(.binding(.set(\.token, "ahc_live_x93k7q7"))) {
      $0.token = "ahc_live_x93k7q7"
      $0.validation = .idle
    }
  }

  @Test func test_connectTapped_emptyOrValidating_doesNothing() async {
    // Empty token → `canSubmit` is false → no state change, no probe.
    let emptyStore = TestStore(initialState: ConnectComponent.State(token: "   ")) {
      ConnectComponent()
    }
    await emptyStore.send(.connectTapped)

    // Already validating → `canSubmit` is false → the tap is ignored (no second probe).
    let busyStore = TestStore(initialState: ConnectComponent.State(token: "ahc_live_x", validation: .validating)) {
      ConnectComponent()
    }
    await busyStore.send(.connectTapped)
  }
}
