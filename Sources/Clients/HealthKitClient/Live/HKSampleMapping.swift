#if canImport(HealthKit)
  import Foundation
  import HealthKit
  import HealthKitClient
  import WireModels

  /// One record-producing HK query: a sample type, the wire `RecordType` it maps to, and the canonical
  /// unit its quantity is read in (`nil` for category samples like sleep).
  struct RecordQuerySpec: Sendable {
    let sampleType: HKSampleType
    let recordType: RecordType
    let unit: HKUnit?
  }

  enum HKSampleMapping {
    /// Every record-producing HK type → its wire `RecordType` + canonical unit. `running_cadence` is
    /// intentionally absent (no first-class `HKQuantityTypeIdentifier`; see `HKTypeCatalog`).
    static var recordQuerySpecs: [RecordQuerySpec] {
      let perMinute = HKUnit.count().unitDivided(by: .minute())
      let kcal = HKUnit.kilocalorie()
      let gram = HKUnit.gram()
      let kilogram = HKUnit.gramUnit(with: .kilo)
      let millisecond = HKUnit.secondUnit(with: .milli)
      let vo2 = HKUnit.literUnit(with: .milli).unitDivided(by: kilogram.unitMultiplied(by: .minute()))
      let effort = kcal.unitDivided(by: kilogram.unitMultiplied(by: .hour()))

      func quantity(
        _ id: HKQuantityTypeIdentifier, _ type: RecordType, _ unit: HKUnit
      ) -> RecordQuerySpec {
        RecordQuerySpec(sampleType: HKQuantityType(id), recordType: type, unit: unit)
      }

      return [
        quantity(.heartRate, .heartRate, perMinute),
        quantity(.heartRateVariabilitySDNN, .heartRateVariabilitySdnn, millisecond),
        quantity(.restingHeartRate, .restingHeartRate, perMinute),
        quantity(.stepCount, .stepCount, .count()),
        quantity(.activeEnergyBurned, .activeEnergyBurned, kcal),
        quantity(.basalEnergyBurned, .basalEnergyBurned, kcal),
        quantity(.physicalEffort, .physicalEffort, effort),
        quantity(.vo2Max, .vo2Max, vo2),
        quantity(.bodyMass, .bodyMass, kilogram),
        quantity(.runningSpeed, .runningSpeed, HKUnit.meter().unitDivided(by: .second())),
        quantity(.runningPower, .runningPower, .watt()),
        quantity(.runningStrideLength, .runningStrideLength, .meter()),
        quantity(.runningGroundContactTime, .runningGroundContactTime, millisecond),
        quantity(.runningVerticalOscillation, .runningVerticalOscillation, .meterUnit(with: .centi)),
        quantity(.respiratoryRate, .respiratoryRate, perMinute),
        quantity(.dietaryEnergyConsumed, .dietaryEnergyConsumed, kcal),
        quantity(.dietaryProtein, .dietaryProtein, gram),
        quantity(.dietaryCarbohydrates, .dietaryCarbohydrates, gram),
        quantity(.dietaryFatTotal, .dietaryFatTotal, gram),
        quantity(.dietaryFiber, .dietaryFiber, gram),
        quantity(.dietarySodium, .dietarySodium, .gramUnit(with: .milli)),
        quantity(.dietaryWater, .dietaryWater, .literUnit(with: .milli)),
        RecordQuerySpec(
          sampleType: HKCategoryType(.sleepAnalysis), recordType: .sleepAnalysis, unit: nil
        ),
      ]
    }

    /// Map an HK sample to a payload tagged with `spec.recordType`.
    static func recordPayload(from sample: HKSample, spec: RecordQuerySpec) -> HealthRecordPayload {
      HealthRecordPayload(
        uuid: sample.uuid.uuidString,
        type: spec.recordType,
        start: sample.startDate,
        end: sample.endDate,
        value: quantityValue(of: sample, unit: spec.unit),
        unit: spec.unit?.unitString,
        category: (sample as? HKCategorySample).map { String($0.value) },
        source: sample.sourceRevision.source.name,
        metadata: sample.metadata?.compactMapValues { String(describing: $0) }
      )
    }

    /// Extract a quantity value, guarded by `is(compatibleWith:)` so a wrong unit yields `nil` (never
    /// a crash). Category samples (no unit) return `nil` here — their value rides the `category` field.
    private static func quantityValue(of sample: HKSample, unit: HKUnit?) -> Double? {
      guard let quantitySample = sample as? HKQuantitySample,
            let unit,
            quantitySample.quantity.is(compatibleWith: unit)
      else { return nil }
      return quantitySample.quantity.doubleValue(for: unit)
    }

    // The size rules are waived for `activityTypeName`: it is one flat compiler-checked
    // case-per-line table, and a lookup dictionary would silence the exhaustiveness guarantee
    // that catches future SDK cases.
    // swiftlint:disable cyclomatic_complexity function_body_length

    /// The wire form of `Workout.type` (plan D3): the snake_case activity-type name the backend's
    /// `_canonical_activity_type` expects (`"running"`, `"high_intensity_interval_training"`).
    /// The backend lowercases un-prefixed input WITHOUT splitting camel boundaries, so bare
    /// camelCase would corrupt — and the numeric `rawValue` string the client used to send
    /// canonicalizes to itself and defeats all backend classification. `HKWorkoutActivityType`
    /// is an @objc enum (no case-name reflection), hence the explicit exhaustive switch;
    /// `@unknown default` falls back to the numeric string (deterministic, never wrong-name).
    static func activityTypeName(_ type: HKWorkoutActivityType) -> String {
      switch type {
      case .americanFootball: "american_football"
      case .archery: "archery"
      case .australianFootball: "australian_football"
      case .badminton: "badminton"
      case .baseball: "baseball"
      case .basketball: "basketball"
      case .bowling: "bowling"
      case .boxing: "boxing"
      case .climbing: "climbing"
      case .cricket: "cricket"
      case .crossTraining: "cross_training"
      case .curling: "curling"
      case .cycling: "cycling"
      case .dance: "dance"
      case .danceInspiredTraining: "dance_inspired_training"
      case .elliptical: "elliptical"
      case .equestrianSports: "equestrian_sports"
      case .fencing: "fencing"
      case .fishing: "fishing"
      case .functionalStrengthTraining: "functional_strength_training"
      case .golf: "golf"
      case .gymnastics: "gymnastics"
      case .handball: "handball"
      case .hiking: "hiking"
      case .hockey: "hockey"
      case .hunting: "hunting"
      case .lacrosse: "lacrosse"
      case .martialArts: "martial_arts"
      case .mindAndBody: "mind_and_body"
      case .mixedMetabolicCardioTraining: "mixed_metabolic_cardio_training"
      case .paddleSports: "paddle_sports"
      case .play: "play"
      case .preparationAndRecovery: "preparation_and_recovery"
      case .racquetball: "racquetball"
      case .rowing: "rowing"
      case .rugby: "rugby"
      case .running: "running"
      case .sailing: "sailing"
      case .skatingSports: "skating_sports"
      case .snowSports: "snow_sports"
      case .soccer: "soccer"
      case .softball: "softball"
      case .squash: "squash"
      case .stairClimbing: "stair_climbing"
      case .surfingSports: "surfing_sports"
      case .swimming: "swimming"
      case .tableTennis: "table_tennis"
      case .tennis: "tennis"
      case .trackAndField: "track_and_field"
      case .traditionalStrengthTraining: "traditional_strength_training"
      case .volleyball: "volleyball"
      case .walking: "walking"
      case .waterFitness: "water_fitness"
      case .waterPolo: "water_polo"
      case .waterSports: "water_sports"
      case .wrestling: "wrestling"
      case .yoga: "yoga"
      case .barre: "barre"
      case .coreTraining: "core_training"
      case .crossCountrySkiing: "cross_country_skiing"
      case .downhillSkiing: "downhill_skiing"
      case .flexibility: "flexibility"
      case .highIntensityIntervalTraining: "high_intensity_interval_training"
      case .jumpRope: "jump_rope"
      case .kickboxing: "kickboxing"
      case .pilates: "pilates"
      case .snowboarding: "snowboarding"
      case .stairs: "stairs"
      case .stepTraining: "step_training"
      case .wheelchairWalkPace: "wheelchair_walk_pace"
      case .wheelchairRunPace: "wheelchair_run_pace"
      case .taiChi: "tai_chi"
      case .mixedCardio: "mixed_cardio"
      case .handCycling: "hand_cycling"
      case .discSports: "disc_sports"
      case .fitnessGaming: "fitness_gaming"
      case .cardioDance: "cardio_dance"
      case .socialDance: "social_dance"
      case .pickleball: "pickleball"
      case .cooldown: "cooldown"
      case .swimBikeRun: "swim_bike_run"
      case .transition: "transition"
      case .underwaterDiving: "underwater_diving"
      case .other: "other"
      @unknown default: String(type.rawValue)
      }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    /// Ordered distance sources for `workoutPayload`. HealthKit stores workout distance under a
    /// per-modality quantity type, and a workout carries statistics only for its own modality's
    /// type — so first-non-nil resolution over this list is exact, not heuristic.
    /// `distanceWalkingRunning` leads as the most common case.
    static let distanceTypeCandidates: [HKQuantityTypeIdentifier] = {
      // Rowing/cross-country-skiing/paddle-sports identifiers need macOS 15 (host tests build at
      // macOS 14; the shipped iOS 26 floor always satisfies the `*` clause, so on-device — and on
      // any modern host runtime — the full list applies).
      guard #available(macOS 15.0, *) else {
        return [
          .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
          .distanceDownhillSnowSports, .distanceWheelchair,
        ]
      }
      return [
        .distanceWalkingRunning,
        .distanceCycling,
        .distanceSwimming,
        .distanceRowing,
        .distanceCrossCountrySkiing,
        .distanceDownhillSnowSports,
        .distancePaddleSports,
        .distanceWheelchair,
      ]
    }()

    /// Pure resolution seam: the first candidate the workout has a distance sum for wins.
    /// Takes a closure (instead of the `HKWorkout`) so tests can inject fixtures — constructed
    /// `HKWorkout`s don't reliably expose `statistics(for:)` off-device.
    static func distanceMeters(sumForType: (HKQuantityTypeIdentifier) -> Double?) -> Double? {
      for candidate in distanceTypeCandidates {
        if let meters = sumForType(candidate) { return meters }
      }
      return nil
    }

    /// Deterministic preference over a workout's related effort samples (D2, validation round-1
    /// #4): any user-logged (`workoutEffortScore`) beats any system-estimated
    /// (`estimatedWorkoutEffortScore`) regardless of dates; newest-by-`date` wins within a class
    /// (inputs are unordered — bare values could not decide "latest wins"); the winning value
    /// (read in `HKUnit.appleEffortScore()`) is rounded to the wire `Int`. Empty inputs → honest
    /// `nil`, never a fabricated score.
    static func preferredEffortScore(
      userLogged: [(date: Date, value: Double)],
      estimated: [(date: Date, value: Double)]
    ) -> Int? {
      let pool = userLogged.isEmpty ? estimated : userLogged
      return pool.max { $0.date < $1.date }.map { Int($0.value.rounded()) }
    }

    /// Effort is resolved by the CALLER (the per-workout effort-relationship read in
    /// `HKDeltaReads`) so this stays a pure, store-free mapping. The old
    /// `metadata["HKWorkoutEffortScore"]` read is gone — that metadata key does not exist in
    /// HealthKit, so it always produced `nil` while looking populated.
    static func workoutPayload(from workout: HKWorkout, effortScore: Int?) -> WorkoutPayload {
      // Distance types are per-modality (cycling/swimming/rowing each carry their own), so
      // resolve across the ordered candidates instead of only `distanceWalkingRunning`.
      let distance = distanceMeters { identifier in
        workout.statistics(for: HKQuantityType(identifier))?
          .sumQuantity()?.doubleValue(for: .meter())
      }
      let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
        .sumQuantity()?.doubleValue(for: .kilocalorie())
      return WorkoutPayload(
        uuid: workout.uuid.uuidString,
        type: activityTypeName(workout.workoutActivityType),
        start: workout.startDate,
        end: workout.endDate,
        durationS: workout.duration,
        distanceM: distance,
        activeEnergyKcal: energy,
        effortScore: effortScore
      )
    }

    static func activityPayload(
      from summary: HKActivitySummary, calendar: Calendar
    ) -> ActivitySummaryPayload {
      let date = summary.dateComponents(for: calendar).date ?? Date(timeIntervalSinceReferenceDate: 0)
      return ActivitySummaryPayload(
        date: date,
        activeEnergyKcal: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
        exerciseMinutes: Int(summary.appleExerciseTime.doubleValue(for: .minute())),
        standHours: Int(summary.appleStandHours.doubleValue(for: .count())),
        steps: nil
      )
    }
  }
#endif
