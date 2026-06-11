import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// Exhaustive coverage (ARCHITECTURE D18) for `NutritionComponent.State` — the pure derivation from the
/// loaded brief: the `macroFocus` target and the **order-preserving** `type == .nutrition` narrative slice
/// (principle #1 / §9.1 — the component selects, the renderer renders verbatim). The component has no
/// actions (render-only, like `SafetyRestComponent`), so these are state-init assertions, not a `TestStore`
/// drive — matching `ReadinessComponentTests`' derived-state style.
@MainActor
struct NutritionComponentTests {
  /// The mapped domain brief for a canned scenario (force-try: an in-bundle fixture decode failure is a
  /// build-time authoring error).
  private func brief(_ scenario: SampleScenario) throws -> DomainModels.DailyBrief {
    try SampleData.dailyBrief(scenario).domain
  }

  /// A `.nutrition` narrative section helper (the fixtures ship none yet — the slice is exercised against a
  /// hand-built `narrative[]`).
  private func section(_ type: DomainModels.NarrativeType, _ heading: String) -> DomainModels.NarrativeSection {
    DomainModels.NarrativeSection(type: type, heading: heading, body: "\(heading) body")
  }

  @Test func test_init_fromLoggedBrief_setsMacroFocusAndNutritionNarrativeSlice() throws {
    let loaded = try brief(.dailyBriefGreen)
    let state = NutritionComponent.State(brief: loaded)
    #expect(state.macroFocus == loaded.macroFocus)
    #expect(state.nutritionNarrative == loaded.narrative.filter { $0.type == .nutrition })
  }

  @Test func test_nutritionNarrativeSlice_preservesOrder_andExcludesOtherTypes() throws {
    var loaded = try brief(.dailyBriefGreen)
    let firstNutrition = section(.nutrition, "Coach note")
    let secondNutrition = section(.nutrition, "Fuel reminder")
    loaded.narrative = [
      section(.summary, "Good morning"),
      firstNutrition,
      section(.session, "Today's session"),
      secondNutrition,
    ]
    let state = NutritionComponent.State(brief: loaded)
    // Exactly the two `.nutrition` sections, in their original relative order, nothing else.
    #expect(state.nutritionNarrative == [firstNutrition, secondNutrition])
    #expect(state.nutritionNarrative.allSatisfy { $0.type == .nutrition })
  }

  @Test func test_nutritionNarrativeSlice_empty_whenNoNutritionSection() throws {
    var loaded = try brief(.dailyBriefGreen)
    loaded.narrative = [
      section(.summary, "Good morning"),
      section(.session, "Today's session"),
      section(.caution, "A gentle note"),
    ]
    let state = NutritionComponent.State(brief: loaded)
    // The panel-only path: no `.nutrition` slice ⇒ the view renders `NutritionGauge` alone, no narrative.
    #expect(state.nutritionNarrative.isEmpty)
  }
}
