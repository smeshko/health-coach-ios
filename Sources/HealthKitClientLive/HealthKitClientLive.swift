import Dependencies
import Foundation
import HealthKitClient

#if canImport(HealthKit)
  import HealthKit

  /// A `Sendable` holder for the (non-`Sendable`) `HKHealthStore`. `HKHealthStore` is thread-safe for
  /// queries/authorization, so an `@unchecked Sendable` box is sound and keeps the `@Sendable` client
  /// closures (and the concurrent delta-read tasks) strict-concurrency-clean.
  final class HealthStoreBox: @unchecked Sendable {
    let store = HKHealthStore()
  }

  extension HealthKitClient: DependencyKey {
    public static let liveValue: HealthKitClient = {
      let box = HealthStoreBox()
      return HealthKitClient(
        isHealthDataAvailable: { HKHealthStore.isHealthDataAvailable() },
        requestAuthorization: {
          guard HKHealthStore.isHealthDataAvailable() else { return }
          try await box.store.requestAuthorization(toShare: [], read: HKTypeCatalog.allReadTypes)
        },
        authorizationStatus: { liveAuthorizationStatus(store: box.store) },
        deltaSamples: { since in try await liveDeltaSamples(box: box, since: since) }
      )
    }()
  }

  /// Fold each category's HK types into one status: authorized if **any** type is authorized, else
  /// denied if any denied, else not-determined. (Apple privacy-masks read status, so this is a
  /// best-effort hint — the real contract is empty-slice-not-error on delta reads.)
  private func liveAuthorizationStatus(
    store: HKHealthStore
  ) -> [HealthDataCategory: HealthAuthorizationStatus] {
    guard HKHealthStore.isHealthDataAvailable() else {
      return Dictionary(
        uniqueKeysWithValues: HealthDataCategory.allCases.map { ($0, .healthDataUnavailable) }
      )
    }
    var result: [HealthDataCategory: HealthAuthorizationStatus] = [:]
    for category in HealthDataCategory.allCases {
      let statuses = category.hkObjectTypes.map { store.authorizationStatus(for: $0) }
      result[category] = foldAuthorizationStatus(statuses)
    }
    return result
  }

  private func foldAuthorizationStatus(
    _ statuses: [HKAuthorizationStatus]
  ) -> HealthAuthorizationStatus {
    if statuses.contains(.sharingAuthorized) { return .sharingAuthorized }
    if statuses.contains(.sharingDenied) { return .sharingDenied }
    return .notDetermined
  }

#else

  // HealthKit is unavailable on this platform (e.g. the macOS host): an empty live client so the
  // package still builds + type-checks. The real reader runs on iOS.
  extension HealthKitClient: DependencyKey {
    public static let liveValue = HealthKitClient(
      isHealthDataAvailable: { false },
      requestAuthorization: {},
      authorizationStatus: {
        Dictionary(
          uniqueKeysWithValues: HealthDataCategory.allCases.map { ($0, .healthDataUnavailable) }
        )
      },
      deltaSamples: { _ in .empty }
    )
  }
#endif
