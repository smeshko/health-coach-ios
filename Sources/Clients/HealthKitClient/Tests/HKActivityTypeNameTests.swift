#if canImport(HealthKit)
  import Foundation
  import HealthKit
  import Testing

  @testable import HealthKitClientLive

  /// Pins the wire form of `Workout.type` (plan D3): the backend's `_canonical_activity_type`
  /// lowercases un-prefixed input WITHOUT splitting camel boundaries, so the client must send
  /// ready-made snake_case name strings (`"high_intensity_interval_training"`) — never bare
  /// camelCase and never the numeric `rawValue` string the live client used to send.
  struct HKActivityTypeNameTests {
    /// Every product-relevant modality → its exact wire string.
    private static let pinned: [(type: HKWorkoutActivityType, name: String)] = [
      (.running, "running"),
      (.walking, "walking"),
      (.hiking, "hiking"),
      (.cycling, "cycling"),
      (.swimming, "swimming"),
      (.rowing, "rowing"),
      (.traditionalStrengthTraining, "traditional_strength_training"),
      (.functionalStrengthTraining, "functional_strength_training"),
      (.highIntensityIntervalTraining, "high_intensity_interval_training"),
      (.coreTraining, "core_training"),
      (.flexibility, "flexibility"),
      (.yoga, "yoga"),
      (.elliptical, "elliptical"),
      (.stairClimbing, "stair_climbing"),
      (.crossTraining, "cross_training"),
      (.boxing, "boxing"),
      (.kickboxing, "kickboxing"),
      (.martialArts, "martial_arts"),
      (.other, "other"),
    ]

    @Test func test_activityTypeName_pinsProductRelevantModalities_toExactWireStrings() {
      for (type, name) in Self.pinned {
        #expect(
          HKSampleMapping.activityTypeName(type) == name,
          "rawValue \(type.rawValue) should map to \"\(name)\""
        )
      }
    }

    /// Sweep every rawValue the iOS 26 SDK defines (1...80, then 82...84 — 81 is unassigned;
    /// `swimBikeRun` is pinned `= 82` in the header — plus `.other` = 3000): no known case may
    /// fall through to the numeric-string fallback, and every name must be lowercase snake_case
    /// (no camel humps to corrupt on the backend).
    @Test func test_activityTypeName_neverNumeric_andAlwaysSnakeCase_forAllKnownCases() {
      let knownRawValues: [UInt] = Array(1...80) + Array(82...84) + [3000]
      for raw in knownRawValues {
        guard let type = HKWorkoutActivityType(rawValue: raw) else {
          Issue.record("rawValue \(raw) unexpectedly not constructible")
          continue
        }
        let name = HKSampleMapping.activityTypeName(type)
        #expect(
          !name.contains(where: { $0.isNumber }),
          "rawValue \(raw) fell through to a numeric string: \"\(name)\""
        )
        #expect(
          name.allSatisfy { ($0.isLowercase && $0.isLetter) || $0 == "_" },
          "rawValue \(raw) is not lowercase snake_case: \"\(name)\""
        )
      }
    }
  }
#endif
