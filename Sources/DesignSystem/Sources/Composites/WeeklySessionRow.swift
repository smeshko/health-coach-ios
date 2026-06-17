import DomainModels
import SwiftUI

/// A compact, **inert** weekly-plan session row (the 2026-06-10 "This Week · Exercise" design) — pure
/// (state in / view out), no actions/gestures. The leading **day chip** (`DayBadge` — solid for a core
/// session, outlined for an extra; terracotta on a hard day, teal otherwise) + the title (`Card.label`) and
/// the `Intensity` sub-line + a trailing **HARD / EASY** badge, over the **target line**: a cardio session
/// (`zoneTarget`) shows "Zone N target · low–high bpm" + the mini Z1–Z5 `SegmentedBar.zones` bar; a
/// strength / no-zone session shows the 1–10 `SegmentedBar.range` effort scale with the band **derived**
/// from the session's zone/intensity (`effortBand` — no invented "RPE N" copy, since `PlannedSession`
/// carries none). The optional duration closes the row.
///
/// Composed entirely from the merged Primitives (`DayBadge`/`SegmentedBar`/`Pill`); adds no new dependency
/// and authors no per-session prose. The parent resolves the row's `ZoneRange` once from the `Zones` map
/// (rows are static — no swap), so this component stays dumb.
public struct WeeklySessionRow: View {
  let session: PlannedSession
  let zoneRange: ZoneRange?

  public init(session: PlannedSession, zoneRange: ZoneRange?) {
    self.session = session
    self.zoneRange = zoneRange
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      // Header row: the day chip + title / intensity + the HARD / EASY badge.
      HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
        if let day = session.suggestedDay {
          DayBadge(day.label, tone: characterTone, isCore: session.tier == .core)
        }
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          Text(session.card.label)
            .font(.coachTextLg)
            .foregroundStyle(.coachForeground)
            .fixedSize(horizontal: false, vertical: true)
          Text(session.intensity.label)
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        Spacer(minLength: CoachSpacing.spaceSm)
        Pill(badgeLabel, tone: characterTone, uppercase: true)
      }
      // The target meter + duration span the **full card width** (under the day chip) — the zone/effort
      // bar is the row's spine, not an indented detail (`Week · Exercise.png`).
      TargetLine(session: session, zoneRange: zoneRange)
      if let duration = durationText {
        Label(duration, systemImage: "clock")
          .font(.coachTextSm)
          .foregroundStyle(.coachForeground)
      }
    }
    .padding(CoachSpacing.spaceMd)
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

  /// HARD on a hard day, else EASY — the badge + the day-chip/target tone follow the session's character
  /// (strength folds into hard/easy by `isHardDay`, matching the 9.1 week-rhythm dot-row; the refreshed
  /// design carries no separate "STRENGTH" treatment).
  private var badgeLabel: String { session.isHardDay ? "Hard" : "Easy" }
  private var characterTone: Tone { session.isHardDay ? .negative : .accent }

  /// "35–45 min" / "45 min" from the optional durations; nil (no chip) when either bound is absent.
  private var durationText: String? {
    guard let low = session.durationMinLow, let high = session.durationMinHigh else { return nil }
    let lower = min(low, high), upper = max(low, high)
    return lower == upper ? "\(lower) min" : "\(lower)–\(upper) min"
  }
}

/// The target line — a cardio zone target (eyebrow + bpm + the mini Z1–Z5 bar) or, for a strength /
/// no-zone session, the 1–10 effort scale with the derived band. A nil `zoneTarget` with a nil derived
/// path never happens (the effort scale always renders for a no-zone session).
private struct TargetLine: View {
  let session: PlannedSession
  let zoneRange: ZoneRange?

  var body: some View {
    if let zone = session.zoneTarget {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        // The zone target is plan data (always shown from `session.zoneTarget`); only the bpm range
        // depends on the optional `zoneRange` (resolved from profile zones, which hydrate after the
        // plan / may be absent — review #2). So a degraded row still states the prescribed zone.
        HStack {
          Text("Zone \(zone.barIndex) target")
            .textCase(.uppercase)
            .tracking(Metrics.eyebrowTracking)
          if let zoneRange {
            Spacer(minLength: CoachSpacing.spaceSm)
            Text("\(zoneRange.low)–\(zoneRange.high) bpm")
          }
        }
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundSubtle)
        SegmentedBar.zones(target: zone.barIndex)
      }
    } else {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        SegmentedBar.range(
          effortBand(zoneTarget: session.zoneTarget, intensity: session.intensity),
          total: Metrics.effortScale,
          tone: .warning
        )
        HStack {
          Text("1 · easy")
          Spacer(minLength: CoachSpacing.spaceSm)
          Text("max · \(Metrics.effortScale)")
        }
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundSubtle)
      }
    }
  }
}

private extension Zone {
  /// The 1…5 ordinal `SegmentedBar.zones(target:)` takes — exhaustive, no `default:`.
  var barIndex: Int {
    switch self {
    case .z1: 1
    case .z2: 2
    case .z3: 3
    case .z4: 4
    case .z5: 5
    }
  }
}

private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.8
  static let effortScale = 10
}
