import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// Exhaustive coverage (ARCHITECTURE D18) for `YesterdayIntakeView`'s pure presence mapping of the optional
/// `intake` onto `DisplayState`: a whole-null intake → `.empty` (the first-class no-food state,
/// §7.4.5/§8.5/§14), a present summary → `.logged` (even with all totals nil — the §5 distinction).
/// `YesterdayIntakeView` is render-only (a plain value-init view, no reducer, like `SafetyRestView`), so
/// these are init-derivation assertions on the view's stored `display`.
@MainActor
struct YesterdayIntakeComponentTests {
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

  /// A present `intakeYesterday` maps to `.logged(summary)` (the fixture's logged intake rides through
  /// verbatim); a whole-null `intakeYesterday` maps to `.empty` — never a `.logged` with zero totals.
  @Test func test_init_loggedAndEmptyMapping() throws {
    let logged = try brief(.dailyBriefGreen)
    let intake = try #require(logged.intakeYesterday)
    #expect(YesterdayIntakeView(intake: intake).display == .logged(intake))

    let noFood = try brief(.dailyBriefNoFood)
    // The fixture itself carries a whole-null intake …
    #expect(noFood.intakeYesterday == nil)
    // … and the mapping takes the `.empty` branch — never a `.logged` with zero totals.
    #expect(YesterdayIntakeView(intake: noFood.intakeYesterday).display == .empty)
  }

  /// §5: a present summary with **all macro totals nil** but `vsTarget` present is `.logged`, never
  /// `.empty` (the `.empty` branch is reserved for a whole-null `intake`). The `.logged` recap then omits
  /// the nil totals — the calories %/protein marker still read from `vsTarget`.
  @Test func test_init_withLoggedIntake_nullMacroTotals_isLogged_notEmpty() {
    let totalsAllNil = summary(caloriesPct: 0.5, proteinHit: false)
    let display = YesterdayIntakeView(intake: totalsAllNil).display
    #expect(display == .logged(totalsAllNil))
    guard case let .logged(logged) = display else {
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
