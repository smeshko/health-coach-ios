import ComposableArchitecture
import Foundation
import HealthKitClient
import Testing

@testable import SettingsFeature

/// Coverage of the HealthKit empty-delta inference (the shared/missing set is derived from delta
/// emptiness, NOT the authorization status map — HK masks read grants) + the open-Health-settings deep
/// link (TASK-003).
@MainActor
struct SettingsHealthTests {
  private static let total = HealthStatusInference.displayedCategories.count

  // MARK: - Pure inference

  @Test func test_healthStatus_allPresent() {
    let status = HealthStatusInference.healthStatus(
      from: SettingsTestFixtures.sampleSet(), status: [:], available: true
    )
    #expect(status.missingCategories == [])
    #expect(status.sharedCount == Self.total)
    #expect(status.totalCount == Self.total)
    #expect(status.available)
  }

  @Test func test_healthStatus_partial_inferredFromEmptyDeltas() {
    // sleep + vo2Max return no samples, but the status map reports them authorized — emptiness wins.
    let authorized = Dictionary(
      uniqueKeysWithValues: HealthStatusInference.displayedCategories.map {
        ($0, HealthAuthorizationStatus.sharingAuthorized)
      }
    )
    let status = HealthStatusInference.healthStatus(
      from: SettingsTestFixtures.sampleSet(missing: [.sleep, .vo2Max]),
      status: authorized,
      available: true
    )
    #expect(Set(status.missingCategories) == [.sleep, .vo2Max])
    #expect(status.sharedCount == Self.total - 2)
  }

  @Test func test_healthStatus_unavailable_allMissing() {
    let status = HealthStatusInference.healthStatus(from: .empty, status: [:], available: false)
    #expect(!status.available)
    #expect(Set(status.missingCategories) == Set(HealthStatusInference.displayedCategories))
    #expect(status.sharedCount == 0)
  }

  // MARK: - TestStore (HK probe via onAppear)

  @Test func test_onAppear_hkFullGrant_noMissing() async {
    let store = makeStore(health: SettingsTestFixtures.fullGrantClient())
    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) { $0.connection.status = .notConnected; $0.connectionResolved = true }
    await store.receive(\.lastSyncLoaded) { $0.lastSyncResolved = true }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsTestFixtures.fullGrant
      $0.healthResolved = true
      $0.load = .loaded
    }
    #expect(store.state.health.missingCategories.isEmpty)
  }

  @Test func test_onAppear_hkDegraded_someMissing() async {
    let store = makeStore(health: SettingsTestFixtures.degradedClient(missing: [.sleep, .vo2Max]))
    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) { $0.connection.status = .notConnected; $0.connectionResolved = true }
    await store.receive(\.lastSyncLoaded) { $0.lastSyncResolved = true }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState(
        available: true,
        sharedCount: Self.total - 2,
        totalCount: Self.total,
        missingCategories: [.sleep, .vo2Max]
      )
      $0.healthResolved = true
      $0.load = .loaded
    }
    #expect(Set(store.state.health.missingCategories) == [.sleep, .vo2Max])
  }

  @Test func test_onAppear_hkUnavailable_allMissing_noDeltaCall() async {
    let deltaCalls = LockIsolated(0)
    let unavailable = HealthKitClient(
      isHealthDataAvailable: { false },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: { _ in deltaCalls.withValue { $0 += 1 }; return .empty }
    )
    let store = makeStore(health: unavailable)
    await store.send(.onAppear) { $0.load = .loading }
    await store.receive(\.connectionLoaded) { $0.connection.status = .notConnected; $0.connectionResolved = true }
    await store.receive(\.lastSyncLoaded) { $0.lastSyncResolved = true }
    await store.receive(\.constantsLoaded) {
      $0.constants = SettingsTestFixtures.loadedConstants
      $0.constantsResolved = true
    }
    await store.receive(\.healthStatusLoaded) {
      $0.health = SettingsFeature.HealthKitStatusState(
        available: false,
        sharedCount: 0,
        totalCount: Self.total,
        missingCategories: HealthStatusInference.displayedCategories
      )
      $0.healthResolved = true
      $0.load = .loaded
    }
    #expect(deltaCalls.value == 0, "no delta read when HealthKit is unavailable")
    #expect(!store.state.health.available)
  }

  @Test func test_openHealthSettingsTapped_callsOpenURL() async {
    let opened = LockIsolated<URL?>(nil)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.openURL = OpenURLEffect { url in
        opened.setValue(url)
        return true
      }
    }
    await store.send(.openHealthSettingsTapped)
    #expect(opened.value?.absoluteString == "x-apple-health://")
  }

  /// A store whose four onAppear loads resolve deterministically; only the HK client varies per test.
  private func makeStore(health: HealthKitClient) -> TestStoreOf<SettingsFeature> {
    TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
      $0.syncRepository.lastSync = { nil }
      $0.profileRepository.profile = { SettingsTestFixtures.sampleProfile() }
      $0.healthKitClient = health
      $0.date = .constant(SettingsTestFixtures.now)
    }
  }
}
