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

  public let since: Date
  /// Exclusive upper bound for the window — `nil` reads open-topped to "now" (the delta default,
  /// byte-identical to the pre-chunking behavior). Chunked backfill (SyncRepository) sets it so a
  /// long window becomes several bounded `[since, until)` reads instead of one truncated read —
  /// the per-type row cap stays, the interface still cannot express an unbounded read.
  public let until: Date?
  /// Always `>= 1` — the init clamps, so HealthKit's no-limit sentinel (`HKObjectQueryNoLimit`
  /// == 0) and negative values are unrepresentable and can never reach an `HKSampleQuery.limit`
  /// (review #2.3: the "cannot express an unbounded read" claim must hold for every input, not
  /// just the default-using call sites).
  public let limitPerType: Int
  public let timeout: Duration

  public init(since: Date, until: Date? = nil, limitPerType: Int, timeout: Duration) {
    self.since = since
    self.until = until
    self.limitPerType = max(1, limitPerType)
    self.timeout = timeout
  }

  /// The standard bounds: everything after `date`, capped by the documented defaults.
  public static func since(_ date: Date) -> HealthReadBounds {
    HealthReadBounds(since: date, limitPerType: defaultLimitPerType, timeout: defaultTimeout)
  }

  /// One backfill chunk: `[start, until)` with the documented defaults. `until == nil` is the
  /// final (open-topped) chunk.
  public static func window(_ start: Date, until: Date?) -> HealthReadBounds {
    HealthReadBounds(since: start, until: until, limitPerType: defaultLimitPerType, timeout: defaultTimeout)
  }

  /// The onboarding **presence-probe** bounds: "is anything there at all", not a delta read. Sized
  /// for presence, not volume: `limitPerType` doubles as the activity-summary window in DAYS
  /// (`activitySince`, 18.2 review #2.2/#3.1), so a presence probe cannot use 1 — activity would
  /// only read "present" with a summary today; 365 keeps "old-but-granted reads present" true for
  /// a year of inactivity while staying firmly bounded. The 10s timeout is below the 15s sync
  /// default because a probe is smaller than a delta read and the user is actively waiting on the
  /// onboarding screen.
  public static func presenceProbe(since date: Date = .distantPast) -> HealthReadBounds {
    HealthReadBounds(since: date, limitPerType: 365, timeout: .seconds(10))
  }

  /// The start of the **activity-summary** window: `since`, floored at `limitPerType - 1` days
  /// before `now`. `HKActivitySummaryQuery` has no `limit` parameter, but summaries are
  /// one-per-day, so bounding the window enforces the same per-type row cardinality as the
  /// sample queries — the `.distantPast` onboarding probe can no longer request an unbounded
  /// activity range (review #2.2; 10 000 days ≈ 27 years, far beyond any device's HK history, so
  /// real probes are semantically unchanged). The floor is `-(limitPerType - 1)` because the
  /// activity predicate is **inclusive at both day endpoints** — `-limitPerType` would span
  /// `limitPerType + 1` distinct days (review #3.1). Falls back to `since` if the calendar
  /// cannot form the floor (never in practice).
  public func activitySince(now: Date, calendar: Calendar) -> Date {
    guard let floor = calendar.date(byAdding: .day, value: -(limitPerType - 1), to: now) else {
      return since
    }
    return max(since, floor)
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
