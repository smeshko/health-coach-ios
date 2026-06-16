import ComposableArchitecture
import Foundation
import NotificationClient
import Sharing
import Testing

@testable import SettingsFeature

/// Exhaustive `TestStore` coverage of the reminders toggle (Phase 10.3): the authorized / provisional /
/// denied / throwing enable paths, disable, no-duplicate-stacking, the revoked-on-appear reflection, and
/// the `@Shared(.appStorage)` persistence. `.serialized` because `@Shared(.appStorage)` is process-global
/// (each test uses a fresh suite).
@Suite(.serialized)
@MainActor
struct RemindersTests {
  private struct Boom: Error {}

  private func recordingClient(
    requestAuthorization: @escaping @Sendable () async throws -> NotificationAuthorizationStatus = { .authorized },
    authorizationStatus: @escaping @Sendable () async -> NotificationAuthorizationStatus = { .authorized }
  ) -> (NotificationClient, RecordingNotificationCenter) {
    var (client, recorder) = NotificationClient.recording()
    client.requestAuthorization = requestAuthorization
    client.authorizationStatus = authorizationStatus
    return (client, recorder)
  }

  @Test func testEnable_authorized_schedulesBoth() async {
    let (client, recorder) = recordingClient(requestAuthorization: { .authorized })
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(true))
    await store.receive(\.authorizationResponse, .authorized) {
      $0.notificationAuthorization = .authorized
      $0.$remindersEnabled.withLock { $0 = true }
    }
    await store.finish()

    #expect(Set(await recorder.scheduledRequests().map(\.id)) == Set(ReminderID.all))
    #expect(store.state.remindersEffectivelyOn)
  }

  @Test func testEnable_provisional_schedulesBoth() async {
    let (client, recorder) = recordingClient(requestAuthorization: { .provisional })
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(true))
    await store.receive(\.authorizationResponse, .provisional) {
      $0.notificationAuthorization = .provisional
      $0.$remindersEnabled.withLock { $0 = true }
    }
    await store.finish()

    #expect(Set(await recorder.scheduledRequests().map(\.id)) == Set(ReminderID.all))
  }

  @Test func testEnable_denied_revertsAndSchedulesNothing() async {
    let (client, recorder) = recordingClient(requestAuthorization: { .denied })
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

    #expect(await recorder.scheduledRequests().isEmpty, "nothing scheduled when denied")
    #expect(!store.state.remindersEnabled)
    #expect(store.state.showEnableInSettingsHint)
  }

  @Test func testEnable_authorizationThrows_revertsAndSchedulesNothing() async {
    let (client, recorder) = recordingClient(requestAuthorization: { throw Boom() })
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(true))
    // A thrown request maps to `.denied` (treated as not-granted) — no crash, nothing scheduled.
    await store.receive(\.authorizationResponse, .denied) {
      $0.notificationAuthorization = .denied
    }

    #expect(await recorder.scheduledRequests().isEmpty)
    #expect(!store.state.remindersEnabled)
  }

  @Test func testDisable_cancelsBoth() async {
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled")
    let (client, recorder) = recordingClient()
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.notificationClient = client
    }

    await store.send(.remindersToggled(false)) {
      $0.$remindersEnabled.withLock { $0 = false }
    }
    await store.finish()

    #expect(Set(await recorder.cancelledIdentifiers()) == Set(ReminderID.all))
  }

  @Test func testEnableTwice_noDuplicateIDs() async {
    let (client, recorder) = recordingClient(requestAuthorization: { .authorized })
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.notificationClient = client
    }

    for _ in 0 ..< 2 {
      await store.send(.remindersToggled(true))
      await store.receive(\.authorizationResponse, .authorized) {
        $0.notificationAuthorization = .authorized
        $0.$remindersEnabled.withLock { $0 = true }
      }
      await store.finish()
    }

    // Id-keyed scheduling replaces — still exactly the two stable IDs, no growth.
    #expect(await recorder.pendingIdentifiers() == ReminderID.all.sorted())
  }

  @Test func testOnAppear_loadsStatus_reflectsRevoked() async {
    let suite = SettingsTestFixtures.freshAppStorage()
    suite.set(true, forKey: "settingsRemindersEnabled") // intent persisted ON
    let (client, _) = recordingClient(authorizationStatus: { .denied }) // but OS revoked
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
    let (client, recorder) = recordingClient(authorizationStatus: { .authorized })
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

  @Test func testOpenNotificationSettings_callsOpenURL() async {
    let opened = LockIsolated<URL?>(nil)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.openURL = OpenURLEffect { url in
        opened.setValue(url)
        return true
      }
    }
    await store.send(.openNotificationSettingsTapped)
    #expect(opened.value?.absoluteString == "app-settings:")
  }

  @Test func testPersistenceSurvivesRelaunch() {
    let suite = SettingsTestFixtures.freshAppStorage()
    withDependencies {
      $0.defaultAppStorage = suite
    } operation: {
      @Shared(.appStorage("settingsRemindersEnabled")) var enabled = false
      $enabled.withLock { $0 = true }
    }
    let reread = withDependencies {
      $0.defaultAppStorage = suite
    } operation: {
      @Shared(.appStorage("settingsRemindersEnabled")) var enabled = false
      return enabled
    }
    #expect(reread, "the persisted toggle survives a store/relaunch")
  }
}
