import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import SettingsFeature

/// Exhaustive `TestStore` coverage of the Phase 10.2 production load: `onAppear` loads the connection,
/// last-sync, and constants slices concurrently from the stubbed interfaces, sending results in a fixed
/// order, and `load` settles to `.loaded` once all three resolve (DECISIONS #5). The notification
/// authorization status is read on the same pass but does not gate the load.
@Suite(.serialized)
@MainActor
struct SettingsLoadTests {
  @Test func test_onAppear_fullLoad_populatesAllSlices() async {
    let profile = SettingsTestFixtures.sampleProfile()
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { profile }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    await store.send(.onAppear) {
      $0.load = .loading
    }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsFeature.ConstantsState(
        age: 34,
        zones: profile.zones,
        restingHrBpm: 48,
        hrvBaselineMs: 92,
        recomputeNoticeWeek: nil
      )
      $0.constantsResolved = true
      $0.load = .loaded
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_onAppear_notConnected_whenTokenNil() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { nil }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .notConnected
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
      $0.load = .loaded
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_onAppear_neverSynced_whenLastSyncNil() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { nil }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = nil
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
      $0.load = .loaded
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_onAppear_constantsLoadFailed_setsFailed() async {
    struct Boom: Error {}
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { throw Boom() }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constantsResolved = true
      $0.load = .failed
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_retryAfterFailedLoad_reloadsAndSucceeds() async {
    // Phase 20.2: a failed load must be recoverable — `retryTapped` (the failed screen's "Try again")
    // restarts the full three-slice load and settles `.loaded` once the repo recovers.
    struct Boom: Error {}
    let profile = SettingsTestFixtures.sampleProfile()
    let profileSucceeds = LockIsolated(false)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = {
        guard profileSucceeds.value else { throw Boom() }
        return profile
      }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    // First load: the constants slice throws → the screen lands `.failed`.
    await receiveConstantsFailedFirstLoad(store)

    // The repo recovers; "Try again" restarts the load from scratch (flags reset, `.loading` shown).
    profileSucceeds.setValue(true)
    await store.send(.retryTapped) {
      $0.load = .loading
      $0.connectionResolved = false
      $0.lastSyncResolved = false
      $0.constantsResolved = false
    }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsFeature.ConstantsState(
        age: 34,
        zones: profile.zones,
        restingHrBpm: 48,
        hrvBaselineMs: 92,
        recomputeNoticeWeek: nil
      )
      $0.constantsResolved = true
      $0.load = .loaded
    }
    // Already `.authorized` from the first pass — received, but no state change to assert.
    await store.receive(\.authorizationStatusLoaded)
  }

  /// Drives the retry test's *first* load to its `.failed` landing: connection + last-sync resolve, the
  /// constants slice throws, and the trailing authorization read arrives.
  private func receiveConstantsFailedFirstLoad(
    _ store: TestStore<SettingsFeature.State, SettingsFeature.Action>
  ) async {
    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constantsResolved = true
      $0.load = .failed
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }

  @Test func test_connectionSlice_storesOnlyMaskedSuffix() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = SettingsTestFixtures.freshAppStorage()
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.date = .constant(SettingsTestFixtures.now)
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    // The stored value is the 4-char suffix, never the full token.
    guard case let .connected(suffix) = store.state.connection.status else {
      Issue.record("expected connected")
      return
    }
    #expect(suffix == "6f2a")
    #expect(!suffix.contains("ahc_live"))
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = SettingsTestFixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
      $0.load = .loaded
    }
    await store.receive(\.authorizationStatusLoaded) {
      $0.notificationAuthorization = .authorized
    }
  }
}
