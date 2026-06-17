import DesignSystem
import DomainModels
import SwiftUI

/// The weekly **Nutrition** segment (the 2026-06-10 "This Week · Nutrition" screen) — the co-equal half of
/// the weekly plan, rendered under 9.1's Exercise | Nutrition toggle when `.nutrition` is selected. Top to
/// bottom: the **"Carb cycling"** card (the `CarbCyclingPattern` chart + the `.nutrition` narrative slice
/// via `NarrativeRenderer`), the **"Steady all week"** constants strip (protein / fat range / hydration
/// range via `RangeFormatter`), the **"Last week"** adherence scorecard (`AdherenceScorecard`, present or
/// the not-enough-data empty state), and the quiet recompute footnote. Pure render — no interactions.
struct WeeklyNutritionView: View {
  let nutrition: WeeklyNutritionComponent.State
  let adherence: AdherenceComponent.State
  /// The plan's `constantsRecomputed` flag — gates the quiet zones/baselines footnote.
  let constantsRecomputed: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // Carb cycling card.
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          Text("Carb cycling")
            .font(.coachText2xl)
            .foregroundStyle(.coachForeground)
          Text("Grams of carbs per day across the week")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        CarbCyclingPattern(dayTypePattern: nutrition.nutrition.dayTypePattern, restDay: nutrition.nutrition.restDay)
        // The nutrition narrative reads as a soft amber "fuel the work" banner (info glyph + verbatim
        // prose), not a bare paragraph — matching `Week · Nutrition.png`.
        if !nutrition.narrative.isEmpty {
          CarbNarrativeBanner(narrative: nutrition.narrative)
        }
      }
      .padding(CoachSpacing.spaceMd)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(CardSurface())

      // Steady all week constants.
      SectionLead(title: "Steady all week", subtitle: "These stay put while carbs cycle")
      SteadyConstants(nutrition: nutrition.nutrition)
        .padding(CoachSpacing.spaceMd)
        .background(CardSurface())

      // Last week adherence scorecard.
      SectionLead(title: "Last week", subtitle: "How the fueling landed")
      AdherenceScorecard(adherence.scorecardState)
        .padding(CoachSpacing.spaceMd)
        .background(CardSurface())

      if constantsRecomputed {
        Text("Your zones and baselines were updated this week.")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// A section lead — a title + a muted sub-line (the "Steady all week" / "Last week" headers).
private struct SectionLead: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(title)
        .font(.coachText2xl)
        .foregroundStyle(.coachForeground)
      Text(subtitle)
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}

/// The "Steady all week" constants — protein (a ≥ floor), fat range, hydration range (via the shipped
/// `RangeFormatter`), each a big value over a tone-colored label (color paired with the value, §9.4).
private struct SteadyConstants: View {
  let nutrition: WeeklyNutrition

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
      ConstantCell(value: "≥\(nutrition.proteinG) g", label: "Protein", tint: .coachAccent)
      ConstantCell(
        value: RangeFormatter.string(low: nutrition.fatGLow, high: nutrition.fatGHigh, unit: "g"),
        label: "Fat", tint: .coachNegative
      )
      ConstantCell(
        value: RangeFormatter.string(
          low: nutrition.hydrationLLow, high: nutrition.hydrationLHigh, unit: "L",
          locale: Locale(identifier: "en_US_POSIX")
        ),
        label: "Hydration", tint: .coachInfo
      )
    }
  }
}

private struct ConstantCell: View {
  let value: String
  let label: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(value)
        .font(.coachTextLg)
        .foregroundStyle(.coachForeground)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.coachTextSm)
        .foregroundStyle(tint)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The carb-cycling narrative as a soft amber banner — a leading info glyph + the section bodies rendered
/// **verbatim** (joined, in order) on the `warningSoft` fill, the carb-load amber carried through icon and
/// text so the "fuel the work, recover the rest" note reads as a tip, not chrome (`Week · Nutrition.png`).
private struct CarbNarrativeBanner: View {
  let narrative: [NarrativeSection]

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      Image(systemName: "info.circle")
        .font(.coachTextMd)
        .foregroundStyle(.coachWarning)
      Text(narrative.map(\.body).joined(separator: "\n\n"))
        .font(.coachTextSm)
        .foregroundStyle(.coachWarning)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous).fill(.coachWarningSoft))
  }
}
