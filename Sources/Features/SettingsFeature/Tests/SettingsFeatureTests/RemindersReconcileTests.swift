import ComposableArchitecture
import Foundation
import NotificationClient
import Testing

@testable import SettingsFeature

/// Reconcile + lifecycle coverage for the reminders toggle (Phase 10.3, review #1–#4): the on-appear
/// revoked reflection, the bidirectional reconcile (re-schedule when intent ∧ granted, cancel otherwise),
/// and the user-intent-wins-over-background-reconcile cancellation races. Split out of `RemindersTests`
/// for the type-body length cap. `.serialized` for the process-global `@Shared(.appStorage)` state.
@Suite(.serialized)
@MainActor
struct RemindersReconcileTests {
  private struct Boom: Error {}

  @Test func testOnAppear_loadsStatus_reflectsRevoked() async {
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled") // intent persisted ON
    let (client, _) = SettingsTestFixtures.recordingClient(authorizationStatus: { .denied }) // but OS revoked
    // Build the State INSIDE withDependencies (via the initialState autoclosure) so its @Shared reads the
    // seeded suite, not the default appStorage.
    let store = TestStore(initialState: {
      var state = SettingsFeature.State()
      state.load = .loaded // reappear branch (no full load)
      return state
    }()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.notificationClient = client
      $0.syncRepository.lastSync = { throw Boom() } // preserve last-sync → only the auth action arrives
    }

    await store.send(.onAppear)
    await store.receive(\.authorizationStatusLoaded, .denied) {
      $0.notificationAuthorization = .denied
    }

    #expect(store.state.remindersEnabled, "intent stays ON")
    #expect(!store.state.remindersEffectivelyOn, "but effective OFF — permission revoked")
    #expect(store.state.showEnableInSettingsHint)
  }

  @Test func testOnAppear_whenEnabledAndGranted_reschedules() async {
    // Reconcile (review #1.1/#1.3): intent ON + granted on appear re-schedules both reminders (idempotent),
    // healing an interrupted enable or a grant made in iOS Settings.
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled")
    let (client, recorder) = SettingsTestFixtures.recordingClient(authorizationStatus: { .authorized })
    let store = TestStore(initialState: {
      var state = SettingsFeature.State()
      state.load = .loaded
      return state
    }()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.notificationClient = client
      $0.syncRepository.lastSync = { throw Boom() } // preserve last-sync → only the auth action arrives
    }

    await store.send(.onAppear)
    await store.receive(\.authorizationStatusLoaded, .authorized) {
      $0.notificationAuthorization = .authorized
    }
    await store.finish()

    #expect(Set(await recorder.scheduledRequests().map(\.id)) == Set(ReminderID.all))
  }

  @Test func testReconcile_doesNotCancelInFlightUserEnable() async {
    // A background reconcile (authorizationStatusLoaded) must NOT cancel a user enable in flight: they use
    // distinct cancel IDs (review #3). Gate `requestAuthorization` so the enable is suspended while the
    // reconcile lands, then release it and assert the enable still schedules both reminders.
    let gate = AsyncStream.makeStream(of: Void.self)
    var (client, recorder) = NotificationClient.recording()
    client.requestAuthorization = {
      for await _ in gate.stream { break }
      return .authorized
    }
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(true)) // requestAuthorization suspends on the gate
    // A background reconcile lands while the enable is suspended (intent still false → cancel branch).
    await store.send(.authorizationStatusLoaded(.authorized)) {
      $0.notificationAuthorization = .authorized
    }
    gate.continuation.yield() // release the auth prompt
    gate.continuation.finish()
    await store.receive(\.authorizationResponse, .authorized) {
      $0.$remindersEnabled.withLock { $0 = true }
    }
    await store.finish()

    #expect(
      Set(await recorder.scheduledRequests().map(\.id)) == Set(ReminderID.all),
      "the user enable still scheduled both reminders despite the concurrent reconcile"
    )
  }

  @Test func testUserToggleOff_cancelsInFlightReconcileEnable() async {
    // A stale background reconcile-enable must not re-add reminders after the user turns them off
    // (review #4): toggling off cancels the in-flight reconcile (CancelID.reconcile).
    let gate = AsyncStream.makeStream(of: Void.self)
    let recorder = RecordingNotificationCenter()
    let client = NotificationClient(
      requestAuthorization: { .authorized },
      authorizationStatus: { .authorized },
      schedule: { request in
        for await _ in gate.stream { break } // suspend the reconcile-enable's schedule
        await recorder.schedule(request)
      },
      cancel: { ids in await recorder.cancel(ids) },
      pendingIdentifiers: { await recorder.pendingIdentifiers() }
    )
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled") // intent ON → reconcile takes the enable branch

    let store = TestStore(initialState: {
      var state = SettingsFeature.State()
      state.load = .loaded
      return state
    }()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.notificationClient = client
      $0.syncRepository.lastSync = { throw Boom() }
    }

    await store.send(.onAppear)
    await store.receive(\.authorizationStatusLoaded, .authorized) {
      $0.notificationAuthorization = .authorized
    }
    // The reconcile-enable is now suspended on the gated schedule. The user toggles OFF.
    await store.send(.remindersToggled(false)) {
      $0.$remindersEnabled.withLock { $0 = false }
    }
    gate.continuation.yield() // release — the cancelled reconcile schedule must NOT record
    gate.continuation.finish()
    await store.finish()

    #expect(await recorder.pendingIdentifiers() == [], "the stale reconcile-enable did not re-add reminders")
  }

  @Test func testOnAppear_whenDisabledButPending_cancels() async {
    // Reconcile heals an interrupted disable (review #2.2): intent OFF on appear cancels any leftover
    // pending reminders so a repeating notification can't keep firing while the toggle shows OFF.
    let (client, recorder) = SettingsTestFixtures.recordingClient(authorizationStatus: { .authorized })
    try? await ReminderScheduler().enable(client) // simulate leftover pending from a prior session
    let store = TestStore(initialState: {
      var state = SettingsFeature.State()
      state.load = .loaded
      return state
    }()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage() // remindersEnabled defaults false
      $0.notificationClient = client
      $0.syncRepository.lastSync = { throw Boom() }
    }

    await store.send(.onAppear)
    await store.receive(\.authorizationStatusLoaded, .authorized) {
      $0.notificationAuthorization = .authorized
    }
    await store.finish()

    #expect(await recorder.pendingIdentifiers() == [], "leftover reminders are cancelled when intent is OFF")
    #expect(Set(await recorder.cancelledIdentifiers()) == Set(ReminderID.all))
  }
  @Test func testEnableDenied_cancelsExistingPending() async {
    // A denied enable is authoritative for OFF — it cancels reminders that may already be pending
    // (review #5), so a repeating reminder can't keep firing while the toggle ends up OFF.
    let (client, recorder) = SettingsTestFixtures.recordingClient(requestAuthorization: { .denied })
    try? await ReminderScheduler().enable(client) // pre-seed pending, as if from a prior session
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(true))
    await store.receive(\.authorizationResponse, .denied) {
      $0.notificationAuthorization = .denied
    }
    await store.finish()

    #expect(await recorder.pendingIdentifiers() == [], "a denied enable cancels existing pending reminders")
  }

  @Test func testReconcileEnable_partialScheduleFailure_revertsToOff() async {
    // A partial schedule failure during the background reconcile-enable must not leave a half-on state
    // (review #6): it reverts to OFF (cancelling the one that succeeded).
    let calls = LockIsolated(0)
    let recorder = RecordingNotificationCenter()
    let client = NotificationClient(
      requestAuthorization: { .authorized },
      authorizationStatus: { .authorized },
      schedule: { request in
        let scheduleCount = calls.withValue { value -> Int in value += 1; return value }
        if scheduleCount == 2 { throw Boom() } // the 2nd add fails after the 1st succeeds
        await recorder.schedule(request)
      },
      cancel: { ids in await recorder.cancel(ids) },
      pendingIdentifiers: { await recorder.pendingIdentifiers() }
    )
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled") // intent ON → reconcile takes the enable branch

    let store = TestStore(initialState: {
      var state = SettingsFeature.State()
      state.load = .loaded
      return state
    }()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.notificationClient = client
      $0.syncRepository.lastSync = { throw Boom() }
    }
    // Non-exhaustive: this interleave (reconcile-enable → partial-failure → self-sent revert) churns
    // @Shared state in a way that's awkward to diff per-action; assert the end state instead.
    store.exhaustivity = .off

    await store.send(.onAppear)
    await store.receive(\.authorizationStatusLoaded)
    // The reconcile-enable's 2nd schedule throws → it reverts intent to OFF (cancelling the 1st).
    await store.receive(\.remindersToggled)
    await store.finish()

    #expect(await recorder.pendingIdentifiers() == [], "a partial schedule failure leaves no half-on state")
    #expect(!store.state.remindersEnabled, "intent reverted to OFF")
  }

}
