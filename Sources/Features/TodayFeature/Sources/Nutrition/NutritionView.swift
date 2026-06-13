import DesignSystem
import DomainModels
import SwiftUI

/// The nutrition target panel (`Today · Nutrition.png`): the "TODAY'S FUEL" card — the `NutritionGauge`
/// donut (kcal center + per-macro ring) and legend (protein/carbs/fat/water with their character notes,
/// fat + hydration as ranges, the day-type chip) on a surface card — followed by the **COACH NOTE** block:
/// the `nutrition` narrative rendered **verbatim** by `NarrativeRenderer` (the eyebrow is the section's
/// `heading`, the design's COACH NOTE treatment; the prose is the model's, principle #1).
///
/// A **render-only** value-init view (no `@Reducer` ceremony): the parent constructs it from the loaded
/// brief. The `init(brief:)` derives the panel input — the always-present `macroFocus` target and the
/// **order-preserving** `type == .nutrition` narrative slice (`Array.filter` keeps order; the renderer
/// never reorders, principle #1). It authors no prose and computes no macro number (§3 / principle #4).
///
/// The gauge owns no card chrome (like `TrendChart`), so the surface card is composed here — mirroring the
/// readiness card. An empty narrative slice renders the panel alone (no placeholder prose).
public struct NutritionView: View {
  /// The day's macro target — always present (openapi marks every `macroFocus` field required), so there
  /// is no empty/null path here (unlike the yesterday recap). Rendered by the `NutritionGauge` panel.
  let macroFocus: DomainModels.MacroFocus
  /// The `type == .nutrition` narrative slice, **in received order**, paired with the panel under the
  /// COACH NOTE eyebrow. Empty ⇒ the panel renders alone (no placeholder prose). Rendered verbatim.
  let nutritionNarrative: [DomainModels.NarrativeSection]

  public init(
    macroFocus: DomainModels.MacroFocus,
    nutritionNarrative: [DomainModels.NarrativeSection]
  ) {
    self.macroFocus = macroFocus
    self.nutritionNarrative = nutritionNarrative
  }

  /// Derive from the loaded brief — the day's `macroFocus` and the **order-preserving** `.nutrition` slice.
  /// The only "logic" is the type filter — no prose authored, no macro number computed (principle #1/#4).
  public init(brief: DomainModels.DailyBrief) {
    self.init(
      macroFocus: brief.macroFocus,
      nutritionNarrative: brief.narrative.filter { $0.type == .nutrition }
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // The "TODAY'S FUEL" card — the gauge on a surface card (the caller owns the chrome).
      NutritionGauge(focus: macroFocus)
        .padding(CoachSpacing.spaceLg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .fill(.coachSurface)
            .overlay(
              RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
                .stroke(.coachBorder, lineWidth: 1)
            )
        )

      // The COACH NOTE block — the nutrition narrative verbatim (the renderer owns the eyebrow from the
      // section heading). An empty slice renders nothing: no placeholder prose (principle #1 / §9.1).
      if !nutritionNarrative.isEmpty {
        NarrativeRenderer(nutritionNarrative)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
