import HealthKitClient

/// Derives the Settings "Apple Health" status from a HealthKit delta probe. HK **masks read grants**
/// (Phase 3.3/6.3), so "shared" is inferred from *emptiness of a delta read*, not the authorization
/// status map — a category that returned ≥1 sample is shared; one that returned nothing is "not shared
/// yet". The status map is only a corroborating hint (PRD §8.5 subtle-hint framing — copy says "shared /
/// not shared yet", never "denied").
enum HealthStatusInference {
  /// The displayed category set, pinned to ONE constant (round-1 #7) so the "N of M" count, the missing
  /// list (which drives the "Manage in Health settings" deep link), and the snapshot seeds can never
  /// drift. The cosmetic count derives from `count`; only the missing list drives behaviour.
  static let displayedCategories: [HealthDataCategory] = [
    .heartRate,
    .hrv,
    .restingHeartRate,
    .sleep,
    .steps,
    .activeEnergy,
    .vo2Max,
    .bodyMass,
    .respiratoryRate,
    .workouts,
    .activity,
  ]

  /// Reduce a delta probe into the displayed status. `available == false` ⇒ every displayed category is
  /// missing (HK unavailable). The `status` map is accepted for corroboration but the missing decision
  /// is driven solely by emptiness, so a granted-but-quiet category is still surfaced as "not shared yet".
  static func healthStatus(
    from set: HealthSampleSet,
    status _: [HealthDataCategory: HealthAuthorizationStatus],
    available: Bool
  ) -> SettingsFeature.HealthKitStatusState {
    guard available else {
      return SettingsFeature.HealthKitStatusState(
        available: false,
        sharedCount: 0,
        totalCount: displayedCategories.count,
        missingCategories: displayedCategories
      )
    }
    let present = displayedCategories.filter { isPresent($0, in: set) }
    let missing = displayedCategories.filter { !present.contains($0) }
    return SettingsFeature.HealthKitStatusState(
      available: true,
      sharedCount: present.count,
      totalCount: displayedCategories.count,
      missingCategories: missing
    )
  }

  /// A category is "shared" when the probe returned at least one sample for it. Workouts/activity have
  /// their own arrays; everything else is record-backed (matched by `RecordType` without naming the wire
  /// type — keeping `WireModels` out of this feature's import surface, §3).
  private static func isPresent(_ category: HealthDataCategory, in set: HealthSampleSet) -> Bool {
    switch category {
    case .workouts:
      return !set.workouts.isEmpty
    case .activity:
      return !set.activity.isEmpty
    default:
      let wanted = category.recordTypes
      return set.records.contains { wanted.contains($0.type) }
    }
  }
}
