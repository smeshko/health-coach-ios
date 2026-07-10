import Dependencies
import Foundation

/// The bounds every HealthKit delta read must carry — the interface cannot express an unbounded
/// read. `since` is the anchor floor (inclusive), `limitPerType` caps the rows returned **per
/// sample type** (newest first — old history is deliberately dropped, matching the backfill-floor
/// philosophy), and `timeout` bounds the **whole read** (all categories together, not per query).
public struct HealthReadBounds: Sendable, Equatable {
  /// The app-wide default per-type row limit (Phase 18.2 DECISIONS — bounded partial read is the
  /// accepted first-sync degradation; delta windows are day-scale and never hit it).
  public static let defaultLimitPerType = 10000
  /// The app-wide default whole-read timeout — must fire *before* the repository's 20s abandoning
  /// backstop so in-flight queries are stopped rather than orphaned.
  public static let defaultTimeout: Duration = .seconds(15)

  public var since: Date
  public var limitPerType: Int
  public var timeout: Duration

  public init(since: Date, limitPerType: Int, timeout: Duration) {
    self.since = since
    self.limitPerType = limitPerType
    self.timeout = timeout
  }

  /// The standard bounds: everything after `date`, capped by the documented defaults.
  public static func since(_ date: Date) -> HealthReadBounds {
    HealthReadBounds(since: date, limitPerType: defaultLimitPerType, timeout: defaultTimeout)
  }
}

/// Thrown by `deltaSamples` **only** when the whole read exceeds `bounds.timeout`. The
/// per-category contract is unchanged: a denied/empty/failing category still contributes an
/// empty slice, never an error (PRD §7.1).
public enum HealthKitReadError: Error, Equatable {
  case timedOut
}

/// The HealthKit data source (D11) — a `Sendable` struct of `@Sendable` closures: availability,
/// authorization request + per-category status (for the degraded-permissions UX), and a delta read
/// of everything newer than the passed-in bounds' anchor. The anchor/watermark is owned by
/// `SyncRepository` (Epic 4.3), not here. `liveValue` lives in `HealthKitClientLive`; the
/// test/preview values use an inline canned fixture and never import HealthKit.
public struct HealthKitClient: Sendable {
  public var isHealthDataAvailable: @Sendable () -> Bool
  public var requestAuthorization: @Sendable () async throws -> Void
  public var authorizationStatus: @Sendable () -> [HealthDataCategory: HealthAuthorizationStatus]
  public var deltaSamples: @Sendable (_ bounds: HealthReadBounds) async throws -> HealthSampleSet

  public init(
    isHealthDataAvailable: @escaping @Sendable () -> Bool,
    requestAuthorization: @escaping @Sendable () async throws -> Void,
    authorizationStatus: @escaping @Sendable () -> [HealthDataCategory: HealthAuthorizationStatus],
    deltaSamples: @escaping @Sendable (_ bounds: HealthReadBounds) async throws -> HealthSampleSet
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
      deltaSamples: { bounds in CannedHealthSamples.cannedSampleSet().filtered(after: bounds.since) }
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
