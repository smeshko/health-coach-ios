import ComposableArchitecture
import Foundation
import Testing

@testable import SettingsFeature

/// Reconnect (token-clear) + reappear (last-sync refresh) coverage, split out of `SettingsLoadTests` for
/// the type-body length cap. `.serialized` for the process-global `@Shared(.appStorage)` state.
@Suite(.serialized)
@MainActor
struct SettingsReconnectRefreshTests {
  @Test func test_reconnectTapped_clearsTokenThenEmitsDelegate() async {
    // The production reconnect must clear the bearer token before bubbling tokenReset (review #1.1) —
    // AppFeature's handler only routes and assumes the session was already cleared.
    let cleared = LockIsolated(false)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.clear = { cleared.setValue(true) }
    }
    await store.send(.reconnectTapped)
    await store.receive(\.delegate, .tokenReset)
    #expect(cleared.value, "the stored token is cleared on re-connect")
  }

  @Test func test_reconnectTapped_whenClearThrows_doesNotEmitDelegate() async {
    // Fail-closed (review #2.1): if the token clear fails, do NOT route to onboarding (that would leave
    // the stale token to resurrect on restart). No delegate is emitted.
    struct Boom: Error {}
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.clear = { throw Boom() }
    }
    await store.send(.reconnectTapped)
    // No `receive(\.delegate)` — the failed clear swallows the route. TestStore asserts no further actions.
  }

  @Test func test_onAppear_whenAlreadyLoaded_refreshesLastSyncOnly() async {
    // Re-entering a loaded Settings refreshes the (stale-prone) last-sync time but does NOT re-run the
    // full load / the expensive HK probe (review #1.3 + #1.2 mitigation).
    var initial = SettingsFeature.State()
    initial.load = .loaded
    initial.connection.status = .connected(tokenSuffix: "6f2a")
    initial.connectionResolved = true
    initial.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
    initial.lastSyncResolved = true
    initial.constants = SettingsTestFixtures.loadedConstants
    initial.constantsResolved = true

    let refreshed = Date(timeIntervalSince1970: 1_790_000_000)
    let store = TestStore(initialState: initial) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.syncRepository.lastSync = { refreshed }
    }

    await store.send(.onAppear)
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = refreshed
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_onAppear_whenLoaded_refreshReadFails_preservesLastSync() async {
    // A transient last-sync read failure on reappear must NOT blank a known timestamp to "Never
    // synced" (review #2.3): only a successful read updates the value.
    struct Boom: Error {}
    var initial = SettingsFeature.State()
    initial.load = .loaded
    initial.connection.status = .connected(tokenSuffix: "6f2a")
    initial.connectionResolved = true
    initial.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
    initial.lastSyncResolved = true
    initial.constants = SettingsTestFixtures.loadedConstants
    initial.constantsResolved = true

    let store = TestStore(initialState: initial) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.syncRepository.lastSync = { throw Boom() }
    }

    await store.send(.onAppear)
    // No `lastSyncLoaded` received — the failed read is swallowed, the displayed timestamp is preserved.
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
    #expect(store.state.lastSync.lastSyncAt == SettingsTestFixtures.syncedAt)
  }
}
