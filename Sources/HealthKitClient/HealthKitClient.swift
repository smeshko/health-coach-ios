import Dependencies
import Foundation

/// The HealthKit data source (D11) — a `Sendable` struct of `@Sendable` closures: availability,
/// authorization request + per-category status (for the degraded-permissions UX), and a delta read
/// of everything newer than a passed-in anchor. The anchor/watermark is owned by `SyncRepository`
/// (Epic 4.3), not here. `liveValue` lives in `HealthKitClientLive`; the test/preview values use an
/// inline canned fixture and never import HealthKit.
public struct HealthKitClient: Sendable {
  public var isHealthDataAvailable: @Sendable () -> Bool
  public var requestAuthorization: @Sendable () async throws -> Void
  public var authorizationStatus: @Sendable () -> [HealthDataCategory: HealthAuthorizationStatus]
  public var deltaSamples: @Sendable (_ since: Date) async throws -> HealthSampleSet

  public init(
    isHealthDataAvailable: @escaping @Sendable () -> Bool,
    requestAuthorization: @escaping @Sendable () async throws -> Void,
    authorizationStatus: @escaping @Sendable () -> [HealthDataCategory: HealthAuthorizationStatus],
    deltaSamples: @escaping @Sendable (_ since: Date) async throws -> HealthSampleSet
  ) {
    self.isHealthDataAvailable = isHealthDataAvailable
    self.requestAuthorization = requestAuthorization
    self.authorizationStatus = authorizationStatus
    self.deltaSamples = deltaSamples
  }
}

extension HealthKitClient: TestDependencyKey {
  /// Deterministic canned data from the interface-local fixture — no HealthKit, no `SampleData`.
  public static var testValue: HealthKitClient {
    HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { CannedHealthSamples.authorizationStatusAllAuthorized() },
      deltaSamples: { since in CannedHealthSamples.cannedSampleSet().filtered(after: since) }
    )
  }

  public static var previewValue: HealthKitClient { testValue }
}

public extension DependencyValues {
  var healthKitClient: HealthKitClient {
    get { self[HealthKitClient.self] }
    set { self[HealthKitClient.self] = newValue }
  }
}
