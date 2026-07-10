#if canImport(HealthKit)
  import Foundation
  import HealthKit
  import Testing

  @testable import HealthKitClientLive

  /// Tests the pure distance-resolution seam behind `workoutPayload`. HealthKit records workout
  /// distance under a per-modality quantity type, and a workout carries statistics only for its
  /// own modality's type — so first-non-nil over the ordered candidates is exact, not heuristic.
  /// Constructed `HKWorkout`s don't reliably expose `statistics(for:)` off-device, so fixtures
  /// inject sums through the `sumForType` closure; only the one-line statistics read in
  /// `workoutPayload` stays unexercised.
  struct HKDistanceCandidatesTests {
    /// A fixture standing in for `workout.statistics(for:)`: non-nil only for the distance
    /// types the workout actually carries.
    private static func sums(
      _ fixture: [HKQuantityTypeIdentifier: Double]
    ) -> (HKQuantityTypeIdentifier) -> Double? {
      { fixture[$0] }
    }

    @Test func test_distanceMeters_cyclingOnlyFixture_returnsCyclingSum() {
      let meters = HKSampleMapping.distanceMeters(
        sumForType: Self.sums([.distanceCycling: 24_531.5])
      )
      #expect(meters == 24_531.5)
    }

    @Test func test_distanceMeters_swimmingOnlyFixture_returnsSwimmingSum() {
      let meters = HKSampleMapping.distanceMeters(
        sumForType: Self.sums([.distanceSwimming: 1_500])
      )
      #expect(meters == 1_500)
    }

    @available(macOS 15.0, *)
    @Test func test_distanceMeters_rowingOnlyFixture_returnsRowingSum() {
      let meters = HKSampleMapping.distanceMeters(
        sumForType: Self.sums([.distanceRowing: 5_000])
      )
      #expect(meters == 5_000)
    }

    @Test func test_distanceMeters_walkingRunningPresent_winsOverLaterCandidates() {
      let meters = HKSampleMapping.distanceMeters(
        sumForType: Self.sums([.distanceWalkingRunning: 10_000, .distanceCycling: 99])
      )
      #expect(meters == 10_000)
    }

    @Test func test_distanceMeters_noStatistics_returnsNil() {
      let meters = HKSampleMapping.distanceMeters(sumForType: Self.sums([:]))
      #expect(meters == nil)
    }

    @available(macOS 15.0, *)
    @Test func test_distanceTypeCandidates_containProductModalities_walkingRunningFirst() {
      let candidates = HKSampleMapping.distanceTypeCandidates
      #expect(candidates.first == .distanceWalkingRunning)
      let productModalities: [HKQuantityTypeIdentifier] = [
        .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing,
      ]
      for identifier in productModalities {
        #expect(candidates.contains(identifier), "missing \(identifier.rawValue)")
      }
    }
  }
#endif
