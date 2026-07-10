import ComposableArchitecture
import DesignSystem
import Foundation
import HealthKitClient
import Testing

@testable import OnboardingFeature

/// Exhaustive coverage for the `HealthKitPriming` state machine, the `PrimingRow` grouping vocabulary,
/// and the `DesignSystem` label boundary (Phase 7.3 TASK-001 — pure transitions only; the authorize +
/// degraded-probe effects are exercised in TASK-002). Host-runnable: no HealthKit, no simulator.
@MainActor
struct HealthKitPrimingTests {
  // MARK: PrimingRow grouping (the degraded-inference seam)

  /// The union of every row's categories **equals** the full `HealthDataCategory` set — every category
  /// has exactly one home (disjoint + exhaustive), incl. `respiratoryRate` (folds into Heart rate) and
  /// `activity` (folds into Active & basal energy).
  @Test func test_primingRows_categoriesAreDisjointAndCoverEveryCategory() {
    var seen = Set<HealthDataCategory>()
    for row in PrimingRow.allCases {
      #expect(!row.categories.isEmpty, "\(row) maps to no category")
      #expect(seen.isDisjoint(with: row.categories), "\(row) double-maps a category")
      seen.formUnion(row.categories)
    }
    #expect(seen == Set(HealthDataCategory.allCases), "rows must cover every HealthDataCategory")
    // Folded from test_runningForm_isSoleHomeOfRunningDynamics (audit MERGE): runningForm is the sole
    // home for runningDynamics (so the row is mandatory, not conditional).
    let runningHomes = PrimingRow.allCases.filter { $0.categories.contains(.runningDynamics) }
    #expect(runningHomes == [.runningForm])
  }

  // MARK: DesignSystem label boundary (no raw machine key reaches a view)

  /// Every `HealthDataCategory` and every `PrimingRow` resolves to a non-empty human title via the
  /// `DesignSystem` boundary, never the raw case name.
  @Test func test_labels_areNonEmpty_andNotRawCaseNames() {
    for category in HealthDataCategory.allCases {
      let label = category.signalLabel
      #expect(!label.title.isEmpty, "\(category) has an empty signal label")
      #expect(label.title != category.rawValue, "\(category) renders its raw value")
      #expect(label.title != String(describing: category), "\(category) renders its raw case name")
      #expect(!label.iconName.isEmpty, "\(category) has no icon")
    }
    for row in PrimingRow.allCases {
      #expect(!row.rowLabel.title.isEmpty, "\(row) has an empty row label")
      #expect(row.rowLabel.title != String(describing: row), "\(row) renders its raw case name")
    }
    for group in PrimingRow.primingGroups {
      #expect(!group.groupLabel.title.isEmpty, "\(group) has an empty group label")
      #expect(!group.groupLabel.subtitle.isEmpty, "\(group) has an empty group subtitle")
    }
  }

  // MARK: Authorize + degraded-detection effects (TASK-002)

  /// Grant: `requestAuthorization` succeeds and the probe returns samples for **every** row → granted →
  /// `finished`.
  @Test func test_grant_allCategoriesPresent_landsGranted_andFinishes() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { true }
      $0.healthKitClient.requestAuthorization = {}
      $0.healthKitClient.authorizationStatus = { HKFixtures.allAuthorized }
      $0.healthKitClient.deltaSamples = { _ in HKFixtures.allPresentSamples }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) {
      $0.phase = .checking
    }
    await store.receive(\.degradedProbeResponse) { $0.phase = .granted }
    await store.receive(\.delegate, .finished)
  }

  /// Partial: the probe returns no `sleep`/`vo2Max` samples (others present) → only those rows are
  /// missing — **derived from empty slices**, NOT the status map (the hint is deliberately
  /// all-`.notDetermined` to prove inference ignores it).
  @Test func test_partial_inferenceFromEmptySlices_ignoresStatusMap() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { true }
      $0.healthKitClient.requestAuthorization = {}
      $0.healthKitClient.authorizationStatus = { HKFixtures.allNotDetermined }
      $0.healthKitClient.deltaSamples = { _ in HKFixtures.sleepAndVo2MaxMissingSamples }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) {
      $0.phase = .checking
    }
    await store.receive(\.degradedProbeResponse) {
      $0.missingRows = [.sleep, .vo2Max]
      $0.phase = .degraded(
        HealthKitPriming.DegradedSummary(missing: [.sleep, .vo2Max])
      )
    }
  }

  /// Deny: `requestAuthorization` throws → straight to fully-degraded **without a probe** (the degraded
  /// path never throws to the UI), and a non-blocking `continueTapped` → `finished`.
  @Test func test_deny_goesFullyDegraded_withoutProbe_andContinues() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { true }
      $0.healthKitClient.requestAuthorization = { throw StubAuthError() }
      $0.healthKitClient.deltaSamples = { _ in
        Issue.record("deltaSamples must not run when authorization fails")
        return .empty
      }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) {
      $0.missingRows = Set(PrimingRow.allCases)
      $0.phase = .degraded(
        HealthKitPriming.DegradedSummary(missing: Set(PrimingRow.allCases))
      )
    }
    await store.send(.continueTapped)
    await store.receive(\.delegate, .finished)
  }

  /// Unavailable: `isHealthDataAvailable() == false` → fully degraded **without** requesting auth or
  /// probing (DECISIONS #2 — `.healthDataUnavailable` is degraded, not an error).
  @Test func test_unavailable_goesFullyDegraded_withoutRequestingAuthOrProbe() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { false }
      $0.healthKitClient.requestAuthorization = {
        Issue.record("requestAuthorization must not run when HK is unavailable")
      }
      $0.healthKitClient.deltaSamples = { _ in
        Issue.record("deltaSamples must not run when HK is unavailable")
        return .empty
      }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) {
      $0.missingRows = Set(PrimingRow.allCases)
      $0.phase = .degraded(
        HealthKitPriming.DegradedSummary(missing: Set(PrimingRow.allCases))
      )
    }
  }

  /// Phase 18.3: the probe runs under the DEDICATED presence-probe bounds — since `.distantPast`
  /// (presence, not a delta window), `limitPerType` 365 (doubles as the activity-summary window in
  /// days — 1 would only read activity "present" with a summary today), timeout 10s (< the 15s sync
  /// default; the user is actively waiting). The stub captures the bounds the reducer requests.
  @Test func test_probe_requestsDedicatedPresenceProbeBounds() async {
    let captured = LockIsolated<[HealthReadBounds]>([])
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { true }
      $0.healthKitClient.requestAuthorization = {}
      $0.healthKitClient.authorizationStatus = { HKFixtures.allAuthorized }
      $0.healthKitClient.deltaSamples = { bounds in
        captured.withValue { $0.append(bounds) }
        return HKFixtures.allPresentSamples
      }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) { $0.phase = .checking }
    await store.receive(\.degradedProbeResponse) { $0.phase = .granted }
    await store.receive(\.delegate, .finished)

    let bounds = captured.value
    #expect(bounds.count == 1, "exactly one one-shot probe read")
    #expect(bounds.first?.since == .distantPast, "presence == anything at all, since the far past")
    #expect(bounds.first?.limitPerType == 365, "a year of activity-summary window days, firmly bounded")
    #expect(bounds.first?.timeout == .seconds(10), "tighter than the 15s sync default — the user waits")
  }

  /// Phase 18.3 pin (the epic's acceptance in TestStore form): a probe `HealthKitReadError.timedOut`
  /// lands `.degraded(all rows)` — the actionable Continue-CTA state — never a stuck `.checking`.
  @Test func test_probeTimedOut_landsFullyDegraded_neverStuckChecking() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.healthKitClient.isHealthDataAvailable = { true }
      $0.healthKitClient.requestAuthorization = {}
      $0.healthKitClient.authorizationStatus = { HKFixtures.allAuthorized }
      $0.healthKitClient.deltaSamples = { _ in throw HealthKitReadError.timedOut }
    }

    await store.send(.connectTapped) { $0.phase = .authorizing }
    await store.receive(\.authorizationResponse) { $0.phase = .checking }
    await store.receive(\.degradedProbeResponse) {
      $0.missingRows = Set(PrimingRow.allCases)
      $0.phase = .degraded(
        HealthKitPriming.DegradedSummary(missing: Set(PrimingRow.allCases))
      )
    }
    // The degraded screen's non-blocking Continue works — the user is never wedged post-timeout.
    await store.send(.continueTapped)
    await store.receive(\.delegate, .finished)
  }

  /// "Open Health settings" opens the `x-apple-health://` deep link via `openURL` (the Continue path
  /// never depends on it succeeding).
  @Test func test_openHealthSettings_opensHealthDeepLink() async {
    let opened = LockIsolated<[URL]>([])
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    } withDependencies: {
      $0.openURL = OpenURLEffect { url in
        opened.withValue { $0.append(url) }
        return true
      }
    }

    await store.send(.openHealthSettingsTapped)
    await store.finish()
    #expect(opened.value == [URL(string: "x-apple-health://")!])
  }

  // MARK: Pure helpers (unit-tested directly — independent of the reducer)

  /// Per-category emptiness derivation, incl. `workouts`/`activity` (not `RecordType`-backed).
  @Test func test_missingRows_derivesPerCategoryEmptinessFromSlices() {
    #expect(missingRows(from: .empty) == Set(PrimingRow.allCases), "empty set → every row missing")
    #expect(missingRows(from: HKFixtures.allPresentSamples) == [], "every category present → no row missing")
    // workouts is not a RecordType — presence comes from the workouts array.
    let onlyWorkouts = missingRows(from: HealthSampleSet(workouts: [HKFixtures.sampleWorkout]))
    #expect(!onlyWorkouts.contains(.workoutsEffort))
    // activity is not a RecordType — presence comes from the activity array (folds into Active & basal).
    let onlyActivity = missingRows(from: HealthSampleSet(activity: [HKFixtures.sampleActivity]))
    #expect(!onlyActivity.contains(.activeBasalEnergy))
  }
}

private struct StubAuthError: Error {}

/// Deterministic, `Sendable`, nonisolated fixtures (fixed timestamps — no wall clock; built via
/// `RecordType` implicit members so the test never names `WireModels`). Kept at file scope so the
/// `@Sendable` dependency stubs in the `@MainActor` test class can reference them.
private enum HKFixtures {
  static let fixedDate = Date(timeIntervalSinceReferenceDate: 1000)

  static let allAuthorized: [HealthDataCategory: HealthAuthorizationStatus] =
    Dictionary(uniqueKeysWithValues: HealthDataCategory.allCases.map { ($0, .sharingAuthorized) })

  static let allNotDetermined: [HealthDataCategory: HealthAuthorizationStatus] =
    Dictionary(uniqueKeysWithValues: HealthDataCategory.allCases.map { ($0, .notDetermined) })

  static let sampleWorkout = WorkoutPayload(
    uuid: "wk", type: "running", start: fixedDate, end: fixedDate, durationS: 100
  )

  static let sampleActivity = ActivitySummaryPayload(
    date: fixedDate, activeEnergyKcal: 100, exerciseMinutes: 10, standHours: 5
  )

  /// One representative record per `RecordType`-backed row (workouts/activity carry the other two rows).
  static let allPresentRecords: [HealthRecordPayload] = [
    HealthRecordPayload(uuid: "hr", type: .heartRate, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "hrv", type: .heartRateVariabilitySdnn, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "rhr", type: .restingHeartRate, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "sleep", type: .sleepAnalysis, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "steps", type: .stepCount, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "active", type: .activeEnergyBurned, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "vo2", type: .vo2Max, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "run", type: .runningSpeed, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "mass", type: .bodyMass, start: fixedDate, end: fixedDate),
    HealthRecordPayload(uuid: "diet", type: .dietaryEnergyConsumed, start: fixedDate, end: fixedDate),
  ]

  static let allPresentSamples = HealthSampleSet(
    records: allPresentRecords, workouts: [sampleWorkout], activity: [sampleActivity]
  )

  /// Every row present **except** `sleep` and `vo2Max` (their records dropped) — drives the partial case.
  static let sleepAndVo2MaxMissingSamples = HealthSampleSet(
    records: allPresentRecords.filter { $0.uuid != "sleep" && $0.uuid != "vo2" },
    workouts: [sampleWorkout],
    activity: [sampleActivity]
  )
}
