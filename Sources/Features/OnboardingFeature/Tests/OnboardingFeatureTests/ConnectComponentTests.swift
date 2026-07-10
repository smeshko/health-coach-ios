import APIClient
import ComposableArchitecture
import Testing
import TokenClient

@testable import OnboardingFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `ConnectComponent` — the load-bearing
/// write→probe→clear ordering (DECISIONS 1), the 401-vs-transport failure discrimination
/// (`.invalid` vs `.unreachable`), the probe-cancellation-on-edit race closure, the binding-reset
/// recovery path, paste, and the `canSubmit` gate. A `CallRecorder` actor records the
/// `TokenClient`/`APIClient` call order so we can assert `write` precedes `probe`, that `clear`
/// runs on failure only, and that a cancelled pending clear never lands after a re-tap's write.
@MainActor
struct ConnectComponentTests {
  /// Records the order of `write` / `probe` / `clear` across the stubbed dependencies.
  private actor CallRecorder {
    private(set) var calls: [String] = []
    func record(_ name: String) { calls.append(name) }
  }

  /// Parks until the surrounding task is cancelled, then throws `CancellationError` — a
  /// CANCELLATION-AWARE suspension for stubs that must sit "in flight" until a `CancelID.probe`
  /// cancellation arrives. (A plain unresumed continuation would hang the test instead of
  /// observing the cancel: `AsyncStream` finishes its iteration when the consuming task is
  /// cancelled, so the loop exits exactly then.)
  private static func parkUntilCancelled() async throws {
    let parked = AsyncStream<Never> { _ in }
    for await _ in parked {}
    try Task.checkCancellation()
  }

  /// Bounded wait until the recorder shows exactly `expected` — lets a test deterministically
  /// order a send AFTER an effect has reached its parked suspension, without hanging forever
  /// when the effect never runs (the RED/regression case records an Issue instead).
  private func waitForCalls(_ recorder: CallRecorder, toEqual expected: [String]) async {
    for _ in 0..<10_000 {
      if await recorder.calls == expected { return }
      await Task.yield()
    }
    let calls = await recorder.calls
    Issue.record("timed out waiting for calls == \(expected); got \(calls)")
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

  /// A 401 (`APIError.unauthorized`) is the ONLY failure that means "token rejected": it clears
  /// the just-written candidate and shows `.invalid`.
  @Test func test_connect_unauthorized_clearsToken_showsInvalid_noConnected() async {
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
    #expect(calls == ["write", "probe", "clear"], "a 401 must clear the just-written candidate")
    // The absence of a received `.delegate(.connected)` is asserted by the exhaustive store (it
    // would fail on any unexpected action).
  }

  /// ANY non-401 failure (transport/offline, a decode failure, the 18.1 unconfigured client's
  /// `APIError.transport`) is a reachability problem, not a token verdict: the candidate is still
  /// cleared for restore-safety (an unvalidated token must not persist — PLAN Decisions), but the
  /// state is `.unreachable`, never `.invalid`.
  @Test(arguments: [APIError.transport("offline"), APIError.decoding("bad payload")])
  func test_connect_nonAuthFailure_clearsToken_showsUnreachable(probeError: APIError) async {
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
    await store.receive(\.probeResponse) { $0.validation = .unreachable }
    await store.finish()

    let calls = await recorder.calls
    #expect(calls == ["write", "probe", "clear"], "a transport failure must still clear the unvalidated candidate")
  }

  /// The stale-probe race closure: an edit while a probe is in flight CANCELS the probe (no late
  /// `probeResponse` may arrive — the exhaustive store fails on any unexpected action) AND clears
  /// the just-written candidate (the cancel-skips-clear persistence hole: cancellation suppresses
  /// the failure arm where the clear used to live).
  @Test func test_editMidProbe_cancelsProbe_andClearsCandidate() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_slow")) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = { await recorder.record("clear") }
      $0.apiClient.probe = {
        await recorder.record("probe")
        try await Self.parkUntilCancelled()
        return true
      }
    }

    await store.send(.connectTapped) { $0.validation = .validating }
    // Deterministically let the probe reach its parked suspension before editing.
    await waitForCalls(recorder, toEqual: ["write", "probe"])

    await store.send(.binding(.set(\.token, "ahc_live_edited"))) {
      $0.token = "ahc_live_edited"
      $0.validation = .idle
    }
    await store.finish()

    let calls = await recorder.calls
    #expect(
      calls == ["write", "probe", "clear"],
      "the edit must cancel the parked probe and clear the unvalidated candidate"
    )
  }

  /// Edit→re-tap ordering: an edit's PENDING clear is itself registered under the probe cancel ID,
  /// so a re-tap cancels it BEFORE writing the new candidate — a detached clear could interleave
  /// write → stray clear → probe and 401 a valid token. The parked clear never completes, so the
  /// recorder shows the write is NOT followed by a stray clear.
  @Test func test_retapAfterEdit_cancelsPendingClear_beforeWriting() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State()) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.write = { _ in await recorder.record("write") }
      $0.tokenClient.clear = {
        await recorder.record("clear-pending")
        try await Self.parkUntilCancelled()
        await recorder.record("clear-done")
      }
      $0.apiClient.probe = {
        await recorder.record("probe")
        return true
      }
    }

    await store.send(.tokenPasted("ahc_live_ok")) { $0.token = "ahc_live_ok" }
    // Deterministically let the paste's clear reach its parked suspension before re-tapping.
    await waitForCalls(recorder, toEqual: ["clear-pending"])

    await store.send(.connectTapped) { $0.validation = .validating }
    await store.receive(\.probeResponse) { $0.validation = .idle }
    await store.receive(\.delegate, .connected)
    await store.finish()

    let calls = await recorder.calls
    #expect(
      calls == ["clear-pending", "write", "probe"],
      "the re-tap must cancel the pending clear before writing — no stray clear may follow the write"
    )
  }

  @Test func test_editingToken_afterError_resetsValidationToIdle() async {
    let recorder = CallRecorder()
    let store = TestStore(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .invalid)) {
      ConnectComponent()
    } withDependencies: {
      $0.tokenClient.clear = { await recorder.record("clear") }
    }

    await store.send(.binding(.set(\.token, "ahc_live_x93k7q7"))) {
      $0.token = "ahc_live_x93k7q7"
      $0.validation = .idle
    }
    await store.finish()

    let calls = await recorder.calls
    #expect(calls == ["clear"], "an edit clears any previously stored candidate")
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
