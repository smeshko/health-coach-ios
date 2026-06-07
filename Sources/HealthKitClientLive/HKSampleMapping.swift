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

    // `zoneMinutes` and per-workout `statistics` are intentionally left empty here: their HK→wire
    // unit mapping is owned by `SyncRepository` (Epic 4.3), which builds the `SyncRequest`. The canned
    // test value carries a stat to exercise the payload *shape*; live enrichment lands in 4.3.
    static func workoutPayload(from workout: HKWorkout) -> WorkoutPayload {
      let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
        .sumQuantity()?.doubleValue(for: .meter())
      let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
        .sumQuantity()?.doubleValue(for: .kilocalorie())
      let effort = (workout.metadata?["HKWorkoutEffortScore"] as? NSNumber)?.intValue
      return WorkoutPayload(
        uuid: workout.uuid.uuidString,
        type: String(workout.workoutActivityType.rawValue),
        start: workout.startDate,
        end: workout.endDate,
        durationS: workout.duration,
        distanceM: distance,
        activeEnergyKcal: energy,
        effortScore: effort,
        zoneMinutes: nil,
        statistics: []
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
