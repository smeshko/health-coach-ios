import DomainModels
import SwiftUI

/// The last-week adherence scorecard (the 2026-06-10 "This Week · Nutrition" retrospective) — pure: state
/// in, view out. `.present` renders the "How the fueling landed" 2×2 metric grid (avg calories vs the
/// week's target, avg protein vs target, protein-hit days N/7, days-on-target N/7 with the over/under
/// split); `.empty` renders the encouraging "not enough data last week" nudge (never zeros, never an
/// error — §14/§8.5).
///
/// Every number is read **verbatim** from `LastWeekNutrition` (principle #4); an individually-`nil` field
/// renders a soft "—", never `0`. The two presentation reads — the calories delta vs target and the
/// on-target count (`7 − over − under`) — are display arithmetic over wire values (the plan's "70 under
/// 2,450" pattern), not nutrition derivations. The design's "✓ Solid week" chip + closing note are server
/// **judgments** with no wire basis here, so they are omitted (the app never judges the week).
public struct AdherenceScorecard: View {
  public enum State: Equatable, Sendable {
    /// `caloriesTarget`/`proteinTarget` are the week's `avgCaloriesKcal`/`proteinG` (passed by the feature).
    case present(LastWeekNutrition, caloriesTarget: Int, proteinTarget: Int)
    case empty
  }

  let state: State

  public init(_ state: State) {
    self.state = state
  }

  public var body: some View {
    switch state {
    case let .present(lastWeek, caloriesTarget, proteinTarget):
      PresentGrid(lastWeek: lastWeek, caloriesTarget: caloriesTarget, proteinTarget: proteinTarget)
    case .empty:
      EmptyState()
    }
  }
}

private struct PresentGrid: View {
  let lastWeek: LastWeekNutrition
  let caloriesTarget: Int
  let proteinTarget: Int

  var body: some View {
    VStack(spacing: CoachSpacing.spaceLg) {
      HStack(alignment: .top, spacing: CoachSpacing.spaceLg) {
        Metric(title: "Avg calories", value: calories, sub: caloriesContext)
        Metric(title: "Avg protein", value: protein, sub: "target \(proteinTarget) g")
      }
      HStack(alignment: .top, spacing: CoachSpacing.spaceLg) {
        Metric(title: "Protein-hit days", value: proteinHitDays, sub: nil)
        Metric(title: "Days on target", value: daysOnTarget, sub: overUnder)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // Each read is verbatim / "—" when its field is nil (never 0).
  private var calories: String { Self.grouped(lastWeek.avgCaloriesKcal) }
  private var protein: String { lastWeek.avgProteinG.map { "\($0) g" } ?? Placeholder.dash }

  /// "70 under 2,450" — the delta vs the week's calorie target (display arithmetic over two wire values;
  /// no judgment word). Omitted when the average is nil.
  private var caloriesContext: String? {
    guard let avg = lastWeek.avgCaloriesKcal else { return nil }
    let delta = caloriesTarget - avg
    let target = Self.grouped(caloriesTarget)
    if delta == 0 { return "matches \(target)" }
    return "\(abs(delta)) \(delta > 0 ? "under" : "over") \(target)"
  }

  /// "4 / 7" — the wire `proteinHitDays` over the fixed 7-day week (the denominator is a presentation
  /// constant, never derived).
  private var proteinHitDays: String {
    lastWeek.proteinHitDays.map { "\($0) / 7" } ?? Placeholder.dash
  }

  /// "4 / 7" — days on target = `7 − over − under` (display arithmetic over the wire over/under counts);
  /// "—" when either count is nil.
  private var daysOnTarget: String {
    guard let over = lastWeek.daysOverTarget, let under = lastWeek.daysUnderTarget else {
      return Placeholder.dash
    }
    return "\(max(7 - over - under, 0)) / 7"
  }

  private var overUnder: String? {
    guard let over = lastWeek.daysOverTarget, let under = lastWeek.daysUnderTarget else { return nil }
    return "\(over) over · \(under) under"
  }

  private static func grouped(_ value: Int?) -> String {
    guard let value else { return Placeholder.dash }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: value as NSNumber) ?? "\(value)"
  }
}

/// One scorecard metric — the title, the big value (or "—"), and an optional muted sub-line.
private struct Metric: View {
  let title: String
  let value: String
  let sub: String?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(title)
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
      Text(value)
        .font(.coachText2xl)
        .foregroundStyle(.coachForeground)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      if let sub {
        Text(sub)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The "not enough data last week" empty state — a calm icon, the headline, the encouraging nudge, and
/// the "No data yet" chip. Never zeros, never an error.
private struct EmptyState: View {
  var body: some View {
    VStack(spacing: CoachSpacing.spaceSm) {
      Image(systemName: "tray")
        .font(.system(size: Metrics.emptyIcon))
        .foregroundStyle(.coachForegroundSubtle)
      Text("Not enough data last week")
        .font(.coachTextLg)
        .foregroundStyle(.coachForeground)
      Text("Log a few more days and your scorecard appears here — averages, protein-hit days, the lot.")
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Chip("No data yet")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, CoachSpacing.spaceMd)
  }

  private enum Metrics {
    static let emptyIcon: CGFloat = 32
  }
}

private enum Placeholder {
  static let dash = "—"
}
