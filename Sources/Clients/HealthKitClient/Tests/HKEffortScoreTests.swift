#if canImport(HealthKit)
  import Foundation
  import Testing

  @testable import HealthKitClientLive

  /// Pins the pure preference seam behind the effort-relationship read (D2, validation round-1
  /// #4): any user-logged effort sample beats any system-estimated one regardless of dates;
  /// newest-by-date wins within a class (inputs arrive unordered); empty inputs yield an honest
  /// `nil`; values (read in `HKUnit.appleEffortScore()`) round to the wire `Int`.
  struct HKEffortScoreTests {
    private static func sample(hour: Double, value: Double) -> (date: Date, value: Double) {
      (date: Date(timeIntervalSinceReferenceDate: hour * 3600), value: value)
    }

    @Test func test_userLogged_beatsEstimated_evenWhenEstimatedIsNewer() {
      let score = HKSampleMapping.preferredEffortScore(
        userLogged: [Self.sample(hour: 1, value: 6)],
        estimated: [Self.sample(hour: 9, value: 9)]
      )
      #expect(score == 6, "any user-logged sample beats any estimated one, dates notwithstanding")
    }

    @Test func test_newestByDate_winsWithinUserLogged_givenUnorderedInputs() {
      let score = HKSampleMapping.preferredEffortScore(
        userLogged: [
          Self.sample(hour: 3, value: 5),
          Self.sample(hour: 7, value: 8),
          Self.sample(hour: 1, value: 2),
        ],
        estimated: []
      )
      #expect(score == 8, "the newest-by-date user-logged value wins over unordered inputs")
    }

    @Test func test_newestByDate_winsWithinEstimated_whenNoUserLoggedExists() {
      let score = HKSampleMapping.preferredEffortScore(
        userLogged: [],
        estimated: [Self.sample(hour: 5, value: 4), Self.sample(hour: 2, value: 9)]
      )
      #expect(score == 4, "the newest-by-date estimated value wins when nothing is user-logged")
    }

    @Test func test_emptyInputs_returnNil() {
      let score = HKSampleMapping.preferredEffortScore(userLogged: [], estimated: [])
      #expect(score == nil, "no related effort samples → honest nil, never a fabricated value")
    }

    @Test func test_values_roundToTheWireInt() {
      #expect(
        HKSampleMapping.preferredEffortScore(
          userLogged: [Self.sample(hour: 1, value: 7.6)], estimated: []
        ) == 8
      )
      #expect(
        HKSampleMapping.preferredEffortScore(
          userLogged: [Self.sample(hour: 1, value: 7.4)], estimated: []
        ) == 7
      )
    }
  }
#endif
