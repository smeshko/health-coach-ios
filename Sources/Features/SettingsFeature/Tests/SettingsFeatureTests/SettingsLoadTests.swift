import ComposableArchitecture
import DomainModels
import Foundation
import HealthKitClient
import Testing

@testable import SettingsFeature

/// Exhaustive `TestStore` coverage of the Phase 10.2 production load: `onAppear` loads the connection,
/// last-sync, constants, and HealthKit slices concurrently from the stubbed interfaces, sending results
/// in a fixed order, and `load` settles to `.loaded` once all four resolve (DECISIONS #5). The HK
/// inference itself is covered in `SettingsHealthTests`; here the HK client is a full-grant stub so the
/// load orchestration is deterministic.
@MainActor
struct SettingsLoadTests {
  @Test func test_onAppear_fullLoad_populatesAllSlices() async {
    let profile = SettingsTestFixtures.sampleProfile()
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { profile }
      $0.healthKitClient = SettingsTestFixtures.fullGrantClient()
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
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_onAppear_notConnected_whenTokenNil() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.healthKitClient = SettingsTestFixtures.fullGrantClient()
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
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_onAppear_neverSynced_whenLastSyncNil() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { nil }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.healthKitClient = SettingsTestFixtures.fullGrantClient()
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
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_onAppear_constantsLoadFailed_setsFailed() async {
    struct Boom: Error {}
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { throw Boom() }
      $0.healthKitClient = SettingsTestFixtures.fullGrantClient()
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
    // Health still resolves, but `load` stays `.failed` (settleLoad guards on it).
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
    }
  }

  @Test func test_connectionSlice_storesOnlyMaskedSuffix() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { SettingsTestFixtures.syncedAt }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.healthKitClient = SettingsTestFixtures.fullGrantClient()
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
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_reconnectTapped_clearsTokenThenEmitsDelegate() async {
    // The production reconnect must clear the bearer token before bubbling tokenReset (review #1.1) —
    // AppFeature's handler only routes and assumes the session was already cleared.
    let cleared = LockIsolated(false)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.clear = { cleared.setValue(true) }
    }
    await store.send(.reconnectTapped)
    await store.receive(\.delegate, .tokenReset)
    #expect(cleared.value, "the stored token is cleared on re-connect")
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
    initial.health = SettingsTestFixtures.fullGrant
    initial.healthResolved = true

    let refreshed = Date(timeIntervalSince1970: 1_790_000_000)
    let store = TestStore(initialState: initial) {
      SettingsFeature()
    } withDependencies: {
      $0.syncRepository.lastSync = { refreshed }
    }

    await store.send(.onAppear)
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = refreshed
    }
  }
}
