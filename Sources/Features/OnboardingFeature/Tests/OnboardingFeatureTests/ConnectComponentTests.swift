import APIClient
import ComposableArchitecture
import TokenClient
import XCTest

@testable import OnboardingFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `ConnectComponent` — the load-bearing
/// write→probe→clear ordering (DECISIONS 1), the success/failure branches, the binding-reset recovery
/// path, paste, and the `canSubmit` gate. A `CallRecorder` actor records the `TokenClient`/`APIClient`
/// call order so we can assert `write` precedes `probe` and that `clear` runs on failure only.
@MainActor
final class ConnectComponentTests: XCTestCase {
  /// Records the order of `write` / `probe` / `clear` across the stubbed dependencies.
  private actor CallRecorder {
    private(set) var calls: [String] = []
    func record(_ name: String) { calls.append(name) }
  }

  func test_connect_validToken_writes_thenProbes_thenEmitsConnected_keepsToken() async {
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
    XCTAssertEqual(calls, ["write", "probe"], "write must precede probe; clear must NOT run on success")
  }

  func test_connect_invalidToken_401_clearsToken_showsError_noConnected() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_bad")) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = { await recorder.record("clear") }
      $0.apiClient.probe = {
        await recorder.record("probe")
        throw APIError.unauthorized
      }
    }

    await store.send(.connectTapped) { $0.validation = .validating }
    await store.receive(\.probeResponse) { $0.validation = .invalid }
    await store.finish()

    let calls = await recorder.calls
    XCTAssertEqual(calls, ["write", "probe", "clear"], "a 401 must clear the just-written candidate")
    // The absence of a received `.delegate(.connected)` is asserted by the exhaustive store (it would
    // fail on any unexpected action).
  }

  func test_connect_transportFailure_clearsToken_showsError_noConnected() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_x")) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = { await recorder.record("clear") }
      $0.apiClient.probe = {
        await recorder.record("probe")
        throw APIError.transport("offline")
      }
    }

    await store.send(.connectTapped) { $0.validation = .validating }
    await store.receive(\.probeResponse) { $0.validation = .invalid }
    await store.finish()

    let calls = await recorder.calls
    XCTAssertEqual(calls, ["write", "probe", "clear"], "a transport failure clears the candidate too")
  }

  func test_editingToken_afterError_resetsValidationToIdle() async {
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .invalid)) {
      ConnectComponent()
    }

    await store.send(.binding(.set(\.token, "ahc_live_x93k7q7"))) {
      $0.token = "ahc_live_x93k7q7"
      $0.validation = .idle
    }
  }

  func test_paste_fillsTokenField() async {
    let store = TestStore(initialState: ConnectComponent.State()) {
      ConnectComponent()
    }

    await store.send(.tokenPasted("ahc_live_pasted")) { $0.token = "ahc_live_pasted" }
  }

  func test_connectTapped_emptyOrValidating_doesNothing() async {
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
