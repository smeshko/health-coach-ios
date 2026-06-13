import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The readiness **card** (`Today · Exercise.png` / `… — Why open.png`): the "READINESS" eyebrow + a
/// "Why ›" affordance (top-right), the score numeral + the colored band **word** ("78 Ready"), the
/// tri-band `SegmentedBar.readiness` meter (Recover / Ease off / Ready with the position marker — color
/// is never the sole signal, PRD §9.4), and the `summary` narrative below ("Good morning …"). When the
/// "why" is expanded, the **itemized penalty breakdown** renders inline.
///
/// **Reconciled at implement-time (Epic 08 reorder):** there is no `DesignSystem.ReadinessGauge` — the
/// tri-band meter is the merged `SegmentedBar.readiness(score:)` primitive (Phase 8.2 / epic 08 ✓), so
/// this card is assembled from that primitive rather than a reworked gauge. The `summary` slice is
/// **parent-filtered** and passed in (the component renders verbatim, principle #1) — it owns no fetching.
public struct ReadinessComponentView: View {
  @Bindable var store: StoreOf<ReadinessComponent>
  /// The `summary` narrative slice ("Good morning …"), filtered + passed by the parent. Rendered verbatim.
  let summary: [NarrativeSection]

  public init(store: StoreOf<ReadinessComponent>, summary: [NarrativeSection] = []) {
    self.store = store
    self.summary = summary
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // Eyebrow + the "Why ›" affordance (chevron rotates down when expanded).
      HStack(alignment: .firstTextBaseline) {
        Text("READINESS")
          .font(.coachText2xs)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundMuted)
        Spacer(minLength: CoachSpacing.spaceSm)
        Button { store.send(.whyTapped) } label: {
          HStack(spacing: CoachSpacing.space2xs) {
            Text("Why")
            Image(systemName: "chevron.right")
              .rotationEffect(.degrees(store.isWhyExpanded ? 90 : 0))
          }
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
        }
        .buttonStyle(.coachPressable)
      }

      // Score numeral + the colored band word ("78 Ready"). The word + the meter's marker keep color
      // from being the sole signal (PRD §9.4).
      HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.spaceSm) {
        Text("\(store.readiness.score)")
          .font(.coachText3xl)
          .foregroundStyle(.coachForeground)
        Text(store.readiness.band.label)
          .font(.coachText2xl)
          .foregroundStyle(store.readiness.band.color)
      }

      SegmentedBar.readiness(score: store.readiness.score)
        .frame(maxWidth: .infinity, alignment: .leading)

      // The itemized "why" breakdown (inline, when expanded) — matches `… — Why open.png`.
      if store.isWhyExpanded {
        WhyBreakdown(rows: store.penaltyRows, total: store.readiness.score)
      }

      // The day's lead narrative ("Good morning …") — rendered verbatim by the DS renderer.
      if !summary.isEmpty {
        NarrativeRenderer(summary)
      }
    }
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
  }
}

/// The itemized "WHAT MOVED YOUR SCORE" breakdown (`… — Why open.png`): the eyebrow annotated "from 100",
/// one row per penalty (an icon + the 5.1 `PenaltyFactor.label` + the signed points "−N"), the "Today's
/// readiness {score}" total row, and the "physiological only … your check-in never lowers this" footnote.
private struct WhyBreakdown: View {
  let rows: [ReadinessComponent.PenaltyRow]
  let total: Int

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      HStack(alignment: .firstTextBaseline) {
        Text("WHAT MOVED YOUR SCORE")
          .font(.coachText2xs)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundMuted)
        Spacer(minLength: CoachSpacing.spaceSm)
        Text("from 100")
          .font(.coachText2xs)
          .foregroundStyle(.coachForegroundSubtle)
      }

      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: CoachSpacing.spaceSm) {
          Image(systemName: Self.icon(for: row.label))
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
            .frame(width: Metrics.rowIconWidth)
          Text(row.label)
            .font(.coachTextMd)
            .foregroundStyle(.coachForeground)
          Spacer(minLength: CoachSpacing.spaceSm)
          // Domain points are positive (the magnitude docked); the leading "−" is rendered here.
          Text("−\(row.points)")
            .font(.coachTextMd)
            .foregroundStyle(.coachNegative)
        }
      }

      Divider().overlay(.coachBorder)

      HStack {
        Text("Today's readiness")
          .font(.coachTextSm)
          .foregroundStyle(.coachForeground)
        Spacer(minLength: CoachSpacing.spaceSm)
        Text("\(total)")
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
      }

      Text("Physiological only — sleep, HRV, resting heart rate and yesterday's load. "
        + "Your check-in never lowers this.")
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundSubtle)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// A presentation icon for a penalty row, keyed off its display label (a presentation derivation, like
  /// `SessionCard`'s header icon — never a `rawValue` leak; the label already went through the 5.1
  /// boundary). Unknown labels fall back to a neutral gauge icon.
  private static func icon(for label: String) -> String {
    switch label {
    case "Short sleep", "Very short sleep": "moon.zzz"
    case "HRV below baseline": "waveform.path.ecg"
    case "Resting HR elevated": "heart"
    case "Hard session yesterday": "figure.run"
    default: "gauge.with.dots.needle.bottom.50percent"
    }
  }
}

/// Named constants — eyebrow tracking + the breakdown row's leading-icon column width.
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.4
  static let rowIconWidth: CGFloat = 20
}
