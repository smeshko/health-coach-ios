import DomainModels
import Foundation
import HealthKitClient
import NotificationClient

@testable import SettingsFeature

/// Shared, non-isolated fixtures for the Settings load/health tests, so the `@Sendable` dependency-stub
/// closures can reach them from `@MainActor` test structs.
enum SettingsTestFixtures {
  /// 2026-06-08 ~09:00 Europe/Sofia.
  static let syncedAt = Date(timeIntervalSince1970: 1_780_898_400)
  /// A fixed "now" for pinning `\.date` (the HK probe window is computed from it).
  static let now = Date(timeIntervalSince1970: 1_780_900_000)
  private static let epoch = Date(timeIntervalSince1970: 0)

  /// A fresh per-test appStorage suite so the `@Shared(.appStorage)` reminders toggle never leaks between
  /// tests / real UserDefaults (process-global state — suites are `.serialized`, mirroring WeeklyFeature).
  static func freshAppStorage() -> UserDefaults {
    let suiteName = "settings-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  /// A recording `NotificationClient` (10.1's value) with overridable authorization closures, paired with
  /// the recorder so reminders tests can assert what was scheduled/cancelled.
  static func recordingClient(
    requestAuthorization: @escaping @Sendable () async throws -> NotificationAuthorizationStatus = { .authorized },
    authorizationStatus: @escaping @Sendable () async -> NotificationAuthorizationStatus = { .authorized }
  ) -> (NotificationClient, RecordingNotificationCenter) {
    var (client, recorder) = NotificationClient.recording()
    client.requestAuthorization = requestAuthorization
    client.authorizationStatus = authorizationStatus
    return (client, recorder)
  }

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

  /// The `ConstantsState` `sampleProfile()` loads into.
  static let loadedConstants = SettingsFeature.ConstantsState(
    age: 34, zones: sampleProfile().zones, restingHrBpm: 48, hrvBaselineMs: 92, recomputeNoticeWeek: nil
  )

  // MARK: - HealthKit fixtures

  private static let total = HealthStatusInference.displayedCategories.count

  /// A delta set covering EVERY displayed category except the ones in `missing` (so the inference marks
  /// exactly `missing` as not-shared). Record-backed categories add a record of one of their record
  /// types; workouts/activity add an element to their arrays.
  static func sampleSet(missing: Set<HealthDataCategory> = []) -> HealthSampleSet {
    var records: [HealthRecordPayload] = []
    var workouts: [WorkoutPayload] = []
    var activity: [ActivitySummaryPayload] = []
    for category in HealthStatusInference.displayedCategories where !missing.contains(category) {
      switch category {
      case .workouts:
        workouts.append(WorkoutPayload(uuid: "w", type: "run", start: epoch, end: epoch, durationS: 1))
      case .activity:
        activity.append(ActivitySummaryPayload(date: epoch, activeEnergyKcal: 1, exerciseMinutes: 1, standHours: 1))
      default:
        if let recordType = category.recordTypes.first {
          records.append(HealthRecordPayload(uuid: category.rawValue, type: recordType, start: epoch, end: epoch))
        }
      }
    }
    return HealthSampleSet(records: records, workouts: workouts, activity: activity)
  }

  /// A HealthKitClient stub returning a full-grant delta set (every displayed category shared).
  static func fullGrantClient() -> HealthKitClient {
    client(set: sampleSet())
  }

  /// A HealthKitClient stub whose delta set omits `missing` (those categories surface as not-shared).
  static func degradedClient(missing: Set<HealthDataCategory>) -> HealthKitClient {
    client(set: sampleSet(missing: missing))
  }

  private static func client(set: HealthSampleSet) -> HealthKitClient {
    HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: { _ in set }
    )
  }

  /// The full-grant status (all displayed categories shared).
  static let fullGrant = SettingsFeature.HealthKitStatusState(
    available: true, sharedCount: total, totalCount: total, missingCategories: []
  )
}
