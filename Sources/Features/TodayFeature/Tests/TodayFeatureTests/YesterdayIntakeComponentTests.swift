import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// Exhaustive coverage (ARCHITECTURE D18) for `YesterdayIntakeComponent.State` — the pure presence mapping
/// of the optional `intakeYesterday` onto `DisplayState` (DECISIONS #2): a whole-null intake → `.empty`
/// (the first-class no-food state, §7.4.5/§8.5/§14), a present summary → `.logged` (even with all totals
/// nil — the §5 distinction). The component computes no nutrition number (principle #4): the protein
/// marker rides `vsTarget.proteinHit` verbatim, independent of the raw `proteinG`.
@MainActor
struct YesterdayIntakeComponentTests {
  private typealias State = YesterdayIntakeComponent.State

  private func brief(_ scenario: SampleScenario) throws -> DomainModels.DailyBrief {
    try SampleData.dailyBrief(scenario).domain
  }

  /// An `IntakeSummary` builder (the §5 cases need hand-built totals the fixtures don't ship).
  private func summary(
    proteinG: Int? = nil,
    caloriesKcal: Int? = nil,
    waterL: Double? = nil,
    fiberG: Int? = nil,
    caloriesPct: Double = 0.9,
    proteinHit: Bool = true
  ) -> DomainModels.IntakeSummary {
    DomainModels.IntakeSummary(
      date: Date(timeIntervalSince1970: 0),
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      fiberG: fiberG,
      waterL: waterL,
      vsTarget: DomainModels.IntakeVsTarget(caloriesPct: caloriesPct, proteinHit: proteinHit)
    )
  }

  @Test func test_init_withLoggedIntake_isLogged() throws {
    let loaded = try brief(.dailyBriefGreen)
    let intake = try #require(loaded.intakeYesterday)
    #expect(State(intakeYesterday: intake).display == .logged(intake))
  }

  @Test func test_init_withNullIntake_isEmpty() throws {
    let loaded = try brief(.dailyBriefNoFood)
    // The fixture itself carries a whole-null intake …
    #expect(loaded.intakeYesterday == nil)
    // … and the mapping takes the `.empty` branch — never a `.logged` with zero totals.
    #expect(State(intakeYesterday: loaded.intakeYesterday).display == .empty)
  }

  /// The protein marker rides `vsTarget.proteinHit`, not the raw `proteinG`: two summaries with **identical**
  /// `proteinG` but opposite `proteinHit` stay distinct through the state (the view reads `proteinHit`
  /// verbatim — D4 / principle #4).
  @Test func test_proteinMarker_tracksVsTargetProteinHit_notRawTotals() {
    let hit = summary(proteinG: 100, proteinHit: true)
    let miss = summary(proteinG: 100, proteinHit: false)

    guard case let .logged(loggedHit) = State(intakeYesterday: hit).display,
          case let .logged(loggedMiss) = State(intakeYesterday: miss).display
    else {
      Issue.record("expected both to be .logged")
      return
    }
    // Same raw protein grams, opposite wire `proteinHit` — the component carries `vsTarget` verbatim.
    #expect(loggedHit.proteinG == loggedMiss.proteinG)
    #expect(loggedHit.vsTarget.proteinHit == true)
    #expect(loggedMiss.vsTarget.proteinHit == false)
  }

  /// §5: a present summary with **all macro totals nil** but `vsTarget` present is `.logged`, never
  /// `.empty` (the `.empty` branch is reserved for a whole-null `intakeYesterday`). The `.logged` recap
  /// then omits the nil totals — the calories %/protein marker still read from `vsTarget`.
  @Test func test_init_withLoggedIntake_nullMacroTotals_isLogged_notEmpty() {
    let totalsAllNil = summary(caloriesPct: 0.5, proteinHit: false)
    let state = State(intakeYesterday: totalsAllNil)
    #expect(state.display == .logged(totalsAllNil))
    guard case let .logged(logged) = state.display else {
      Issue.record("expected .logged")
      return
    }
    // Every total is nil, but the `vsTarget` recap is intact (no force-unwrap, no fallback to zeros).
    #expect(logged.caloriesKcal == nil)
    #expect(logged.proteinG == nil)
    #expect(logged.waterL == nil)
    #expect(logged.fiberG == nil)
    #expect(logged.vsTarget.caloriesPct == 0.5)
  }
}
