import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import SettingsFeature

/// Exhaustive `TestStore` coverage of the Phase 10.2 production load: `onAppear` loads the connection,
/// last-sync, constants, and HealthKit slices from the stubbed interfaces, and `load` settles to
/// `.loaded` once all four resolve (DECISIONS #5). The HK probe is stubbed in TASK-001 (yields a default
/// `HealthKitStatusState`); its real empty-delta inference + the re-connect/open-Health effects are
/// TASK-003.
/// Non-isolated fixtures so the `@Sendable` dependency-stub closures can reach them from a `@MainActor`
/// test struct.
private enum Fixtures {
  /// 2026-06-08 ~09:00 Europe/Sofia.
  static let syncedAt = Date(timeIntervalSince1970: 1_780_898_400)

  static func sampleProfile(recomputeWeek: String? = nil) -> DomainModels.Profile {
    DomainModels.Profile(
      athlete: .init(age: 34, sex: "male", heightCm: 180, goalWeightKg: 75),
      zones: .init(
        z1: .init(low: 100, high: 133),
        z2: .init(low: 134, high: 151),
        z3: .init(low: 152, high: 167),
        z4: .init(low: 168, high: 180),
        z5: .init(low: 181, high: 195)
      ),
      thresholds: .init(
        maxHr: 195,
        rhrBaseline: 48,
        hrvBaselineMs: 92,
        easyHrCap: 150,
        cadenceCurrentSpm: 170,
        cadenceTargetSpm: 180
      ),
      meta: .init(constitutionVersion: "v1", constantsRecomputedWeek: recomputeWeek)
    )
  }
}

@MainActor
struct SettingsLoadTests {
  @Test func test_onAppear_fullLoad_populatesAllSlices() async {
    let profile = Fixtures.sampleProfile()
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { Fixtures.syncedAt }
      $0.profileRepository.profile = { profile }
    }

    await store.send(.onAppear) {
      $0.load = .loading
    }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = Fixtures.syncedAt
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
      $0.health = SettingsFeature.HealthKitStatusState()
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_onAppear_notConnected_whenTokenNil() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
      $0.syncRepository.lastSync = { Fixtures.syncedAt }
      $0.profileRepository.profile = { Fixtures.sampleProfile() }
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .notConnected
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = Fixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsFeature.ConstantsState(
        age: 34, zones: Fixtures.sampleProfile().zones, restingHrBpm: 48, hrvBaselineMs: 92
      )
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState()
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
      $0.profileRepository.profile = { Fixtures.sampleProfile() }
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
      $0.constants = SettingsFeature.ConstantsState(
        age: 34, zones: Fixtures.sampleProfile().zones, restingHrBpm: 48, hrvBaselineMs: 92
      )
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState()
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
      $0.syncRepository.lastSync = { Fixtures.syncedAt }
      $0.profileRepository.profile = { throw Boom() }
    }

    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) {
      $0.connection.status = .connected(tokenSuffix: "6f2a")
      $0.connectionResolved = true
    }
    await store.receive(\.lastSyncLoaded) {
      $0.lastSync.lastSyncAt = Fixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constantsResolved = true
      $0.load = .failed
    }
    // Health still resolves, but `load` stays `.failed` (settleLoad guards on it).
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState()
      $0.healthResolved = true
    }
  }

  @Test func test_connectionSlice_storesOnlyMaskedSuffix() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { "ahc_live_abcd6f2a" }
      $0.syncRepository.lastSync = { Fixtures.syncedAt }
      $0.profileRepository.profile = { Fixtures.sampleProfile() }
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
      $0.lastSync.lastSyncAt = Fixtures.syncedAt
      $0.lastSyncResolved = true
    }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsFeature.ConstantsState(
        age: 34, zones: Fixtures.sampleProfile().zones, restingHrBpm: 48, hrvBaselineMs: 92
      )
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState()
      $0.healthResolved = true
      $0.load = .loaded
    }
  }

  @Test func test_reconnectTapped_emitsDelegate() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    }
    await store.send(.reconnectTapped)
    await store.receive(\.delegate, .tokenReset)
  }
}
