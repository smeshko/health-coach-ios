import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// Exhaustive coverage (ARCHITECTURE D18) for `NutritionView`'s pure derivation from the loaded brief — the
/// `macroFocus` target and the **order-preserving** `type == .nutrition` narrative slice (principle #1 /
/// §9.1 — the view selects, the renderer renders verbatim). `NutritionView` is render-only (a plain
/// value-init view, no reducer, like `SafetyRestView`), so these are init-derivation assertions on the
/// view's stored `macroFocus`/`nutritionNarrative`.
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

  /// The slice is **order-preserving** and excludes other types: a hand-built `narrative[]` with two
  /// `.nutrition` sections interleaved with other types yields exactly those two, in their original order.
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
    let view = NutritionView(brief: loaded)
    // The target rides through verbatim, and exactly the two `.nutrition` sections in original order.
    #expect(view.macroFocus == loaded.macroFocus)
    #expect(view.nutritionNarrative == [firstNutrition, secondNutrition])
    #expect(view.nutritionNarrative.allSatisfy { $0.type == .nutrition })
  }

  @Test func test_nutritionNarrativeSlice_empty_whenNoNutritionSection() throws {
    var loaded = try brief(.dailyBriefGreen)
    loaded.narrative = [
      section(.summary, "Good morning"),
      section(.session, "Today's session"),
      section(.caution, "A gentle note"),
    ]
    let view = NutritionView(brief: loaded)
    // The panel-only path: no `.nutrition` slice ⇒ the view renders `NutritionGauge` alone, no narrative.
    #expect(view.nutritionNarrative.isEmpty)
  }
}
