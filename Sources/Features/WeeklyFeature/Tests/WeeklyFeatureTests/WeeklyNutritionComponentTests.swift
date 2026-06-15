import DomainModels
import Foundation
import Testing

@testable import WeeklyFeature

/// The weekly-nutrition sub-component's derivation: it carries the plan's `WeeklyNutrition` verbatim and
/// the **order-preserving** `type == .nutrition` slice of the plan's narrative (the renderer never
/// reorders/self-filters — 5.4).
struct WeeklyNutritionComponentTests {
  @Test func test_make_carriesNutritionVerbatim() throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let state = WeeklyNutritionComponent.make(from: plan)
    #expect(state.nutrition == plan.nutrition)
  }

  @Test func test_make_filtersNutritionNarrativeSliceInOrder() throws {
    var plan = try WeeklyTestSupport.deloadPlan()
    plan.narrative = [
      NarrativeSection(type: .plan, heading: "", body: "plan lead"),
      NarrativeSection(type: .nutrition, heading: "", body: "first nutrition note"),
      NarrativeSection(type: .caution, heading: "", body: "a caution"),
      NarrativeSection(type: .nutrition, heading: "", body: "second nutrition note"),
    ]
    let state = WeeklyNutritionComponent.make(from: plan)
    #expect(state.narrative == [
      NarrativeSection(type: .nutrition, heading: "", body: "first nutrition note"),
      NarrativeSection(type: .nutrition, heading: "", body: "second nutrition note"),
    ])
    #expect(state.narrative.allSatisfy { $0.type == .nutrition }, "only the nutrition slice")
  }
}
