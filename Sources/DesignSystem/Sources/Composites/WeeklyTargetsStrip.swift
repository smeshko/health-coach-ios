import DomainModels
import SwiftUI

/// The weekly **targets strip** (the "Weekly targets — What a good week adds up to" section of the
/// 2026-06-10 "This Week · Exercise" design) — pure (state in / view out). The "80% easy" split (the
/// `easyRunRatio` made measurable, PRD §7.5.3) as a two-segment bar + a "N% easy · M% hard" label (text,
/// so color is never the sole cue, §9.4), then the metric cells: total run km (omitted when nil — never
/// "nil km"), strength sessions, hard days, and the cadence cue ("~<spm> spm"). Numeric strings are
/// card-authored UX over numeric data, not enum→label.
public struct WeeklyTargetsStrip: View {
  let targets: WeeklyTargets

  public init(targets: WeeklyTargets) {
    self.targets = targets
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      EasyHardSplit(easyRatio: targets.easyRunRatio)
      HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
        if let totalRunKm = targets.totalRunKm {
          MetricCell(value: Self.kmText(totalRunKm), label: "Total")
        }
        MetricCell(value: "\(targets.strengthSessions)", label: "Strength")
        MetricCell(value: "\(targets.hardDays)", label: "Hard days")
        MetricCell(value: "~\(targets.cadenceSpm) spm", label: "Cadence")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// "38 km" / "11.5 km" — drop a trailing `.0` (whole km read cleaner) without a locale-variant decimal.
  private static func kmText(_ value: Double) -> String {
    value == value.rounded() ? "\(Int(value)) km" : "\(value) km"
  }
}

/// The easy-vs-hard split: a two-weighted-segment `SegmentedBar` (easy accent / hard negative) under the
/// "N% easy · M% hard" label. The hard share is `1 - easyRunRatio`.
private struct EasyHardSplit: View {
  let easyRatio: Double

  var body: some View {
    let easyPct = Int((easyRatio * 100).rounded())
    VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
      HStack {
        Text("\(easyPct)% easy")
          .foregroundStyle(.coachAccent)
        Spacer(minLength: CoachSpacing.spaceSm)
        Text("\(100 - easyPct)% hard")
          .foregroundStyle(.coachNegative)
      }
      .font(.coachTextSm)
      // Two weighted segments via the in-module primitive init (not a new visual) — a hairline floor on
      // each weight so a 100/0 split still shows a sliver of the other tone.
      SegmentedBar(segments: [
        SegmentedBar.Segment(weight: max(easyRatio, Metrics.minWeight), color: .coachAccent),
        SegmentedBar.Segment(weight: max(1 - easyRatio, Metrics.minWeight), color: .coachNegative),
      ])
    }
  }

  private enum Metrics {
    static let minWeight: CGFloat = 0.02
  }
}

/// One metric cell — a bold value over a muted caption, sharing the row's width.
private struct MetricCell: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(value)
        .font(.coachTextLg)
        .foregroundStyle(.coachForeground)
        // Keep every cell a uniform single value line — a wider value ("~180 spm") shrinks to fit its
        // equal-width column rather than wrapping to a taller cell than its neighbours.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundMuted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
