#if canImport(HealthKit)
  import HealthKit
  import HealthKitClient

  extension HealthDataCategory {
    /// The HealthKit object types this category reads. The **only** place HK type identifiers live.
    ///
    /// Note: `running_cadence` is a wire `RecordType` but has **no** first-class
    /// `HKQuantityTypeIdentifier` (HealthKit derives cadence), so `runningDynamics` cannot read it —
    /// that wire type is knowingly never produced (documented; verified in the TASK-005 manual check),
    /// not an accidental drop.
    var hkObjectTypes: [HKObjectType] {
      switch self {
      case .heartRate: [HKQuantityType(.heartRate)]
      case .hrv: [HKQuantityType(.heartRateVariabilitySDNN)]
      case .restingHeartRate: [HKQuantityType(.restingHeartRate)]
      case .sleep: [HKCategoryType(.sleepAnalysis)]
      case .steps: [HKQuantityType(.stepCount)]
      case .activeEnergy: [HKQuantityType(.activeEnergyBurned)]
      case .basalEnergy: [HKQuantityType(.basalEnergyBurned)]
      case .effort: [HKQuantityType(.physicalEffort)]
      case .vo2Max: [HKQuantityType(.vo2Max)]
      case .bodyMass: [HKQuantityType(.bodyMass)]
      case .runningDynamics:
        [
          HKQuantityType(.runningSpeed), HKQuantityType(.runningPower),
          HKQuantityType(.runningStrideLength), HKQuantityType(.runningGroundContactTime),
          HKQuantityType(.runningVerticalOscillation),
        ]
      case .respiratoryRate: [HKQuantityType(.respiratoryRate)]
      case .dietary:
        [
          HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
          HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal),
          HKQuantityType(.dietaryFiber), HKQuantityType(.dietarySodium),
          HKQuantityType(.dietaryWater),
        ]
      case .workouts: [HKObjectType.workoutType()]
      case .activity: [HKObjectType.activitySummaryType()]
      }
    }
  }

  /// The HealthKit read set (`toShare:` is always empty — the app is read-only for HK, PRD §5).
  enum HKTypeCatalog {
    static var allReadTypes: Set<HKObjectType> {
      Set(HealthDataCategory.allCases.flatMap(\.hkObjectTypes))
    }
  }
#endif
