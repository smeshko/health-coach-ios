import DomainModels
import Foundation
import Testing

@testable import WeeklyFeature

/// The adherence sub-component's present/empty derivation (the load-bearing §14 branch) — a typed
/// `DisplayState`, not a view-only `nil` check, so it is exhaustively assertable.
struct AdherenceComponentTests {
  @Test func test_make_presentWhenLastWeekPopulated() {
    let lastWeek = LastWeekNutrition(
      avgCaloriesKcal: 2380, avgProteinG: 158, proteinHitDays: 4, daysOverTarget: 2, daysUnderTarget: 1
    )
    let state = AdherenceComponent.make(from: Self.nutrition(lastWeek: lastWeek))
    #expect(state.displayState == .present(lastWeek))
    #expect(state.caloriesTarget == 2400) // the week's avgCaloriesKcal
    #expect(state.proteinTarget == 170) // the week's proteinG
  }

  @Test func test_make_emptyWhenLastWeekNil() {
    let state = AdherenceComponent.make(from: Self.nutrition(lastWeek: nil))
    #expect(state.displayState == .empty)
  }

  @Test func test_make_presentEvenWhenSomeFieldsNil() {
    // A present object with individually-nil fields is still `.present` (distinct from the whole-object
    // empty state) — the scorecard renders "—" for the nil fields, never `0`.
    let lastWeek = LastWeekNutrition(
      avgCaloriesKcal: 2380, avgProteinG: nil, proteinHitDays: nil, daysOverTarget: nil, daysUnderTarget: nil
    )
    let state = AdherenceComponent.make(from: Self.nutrition(lastWeek: lastWeek))
    #expect(state.displayState == .present(lastWeek))
  }

  @Test func test_scorecardState_mapsPresentAndEmpty() {
    let lastWeek = LastWeekNutrition(avgCaloriesKcal: 2380)
    let present = AdherenceComponent.make(from: Self.nutrition(lastWeek: lastWeek))
    #expect(present.scorecardState == .present(lastWeek, caloriesTarget: 2400, proteinTarget: 170))
    let empty = AdherenceComponent.make(from: Self.nutrition(lastWeek: nil))
    #expect(empty.scorecardState == .empty)
  }

  private static func nutrition(lastWeek: LastWeekNutrition?) -> WeeklyNutrition {
    WeeklyNutrition(
      proteinG: 170, fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5,
      avgCaloriesKcal: 2400, lastWeek: lastWeek
    )
  }
}
