import DesignSystem
import DomainModels
import Foundation
import SwiftUI
import WidgetSnapshotClient

/// The Phase 21.4 weekly-overview widget view (systemMedium): week label, budgets, key targets, and
/// the core sessions with their suggested weekdays. Plan-only — NEVER used-vs-budget progress (epic
/// Out of scope); extras never reach it (the store's weekly merge carries `core` only). A deload week
/// gets the calm-moon warning pill (the `PlanCard` convention). Plain SwiftUI (not WidgetKit-guarded)
/// so the snapshot target renders it; `widgetURL` is applied by the wrapper in `WeeklyWidget.swift`.
public struct WeeklyWidgetView: View {
  let weekly: WidgetWeeklySnapshot?
  let isStale: Bool

  public init(weekly: WidgetWeeklySnapshot?, isStale: Bool) {
    self.weekly = weekly
    self.isStale = isStale
  }

  public var body: some View {
    Group {
      if let weekly, !isStale {
        WeeklyPlanContent(weekly: weekly)
      } else {
        WeeklyPlaceholder()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
  }
}

/// The populated layout: the week-label header (+ deload pill), then budgets/targets beside the
/// core-session list.
private struct WeeklyPlanContent: View {
  let weekly: WidgetWeeklySnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      HStack(spacing: CoachSpacing.spaceSm) {
        Text(weekLabel)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Spacer(minLength: CoachSpacing.spaceSm)
        if weekly.budgets.deload {
          Pill("Deload", tone: .warning, leading: .icon("moon.fill"), uppercase: true)
        }
      }
      HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          EyebrowedLines(title: "BUDGETS", lines: budgetLines)
          EyebrowedLines(title: "TARGETS", lines: [targetsLine])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        CoreSessionList(sessions: weekly.coreSessions)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  /// "Week 30" from the canonical `"2026-W30"` key; the raw key if it ever fails to parse.
  private var weekLabel: String {
    guard
      let range = weekly.isoWeek.range(of: "-W"),
      let week = Int(weekly.isoWeek[range.upperBound...])
    else { return weekly.isoWeek }
    return "Week \(week)"
  }

  /// "2 hard days · 3 strength" + "Long run 14 km" (dropped when unset — never "nil km").
  private var budgetLines: [String] {
    var lines = ["\(weekly.budgets.hardDays) hard days · \(weekly.budgets.strengthSessions) strength"]
    if let longRunKm = weekly.budgets.longRunKm {
      lines.append("Long run \(kmText(longRunKm))")
    }
    return lines
  }

  /// "30 km run · ~170 spm" (the km leg dropped when unset).
  private var targetsLine: String {
    let cadence = "~\(weekly.targets.cadenceSpm) spm"
    guard let totalRunKm = weekly.targets.totalRunKm else { return cadence }
    return "\(kmText(totalRunKm)) run · \(cadence)"
  }

  /// "14 km" / "11.5 km" — drop a trailing `.0` (the `WeeklyTargetsStrip` convention).
  private func kmText(_ value: Double) -> String {
    value == value.rounded() ? "\(Int(value)) km" : "\(value) km"
  }
}

/// An uppercase eyebrow caption over its single-line values.
private struct EyebrowedLines: View {
  let title: String
  let lines: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(title)
        .font(.coachText2xs)
        .tracking(1)
        .foregroundStyle(.coachForegroundSubtle)
      ForEach(lines, id: \.self) { line in
        Text(line)
          .font(.coachTextSm)
          .foregroundStyle(.coachForeground)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
  }
}

/// The core sessions with their suggested weekdays — capped to what a medium widget holds; the
/// overflow collapses to a "+N more" line. A day-less session shows an em-dash day slot.
private struct CoreSessionList: View {
  let sessions: [PlannedSession]

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text("CORE SESSIONS")
        .font(.coachText2xs)
        .tracking(1)
        .foregroundStyle(.coachForegroundSubtle)
      if sessions.isEmpty {
        Text("—")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
      ForEach(Array(sessions.prefix(Metrics.visibleCap).enumerated()), id: \.offset) { _, session in
        HStack(spacing: CoachSpacing.spaceXs) {
          Text(session.suggestedDay?.label ?? "—")
            .font(.coachText2xs)
            .foregroundStyle(.coachForegroundMuted)
            .frame(width: Metrics.dayColumn, alignment: .leading)
          Text(session.card.label)
            .font(.coachTextSm)
            .foregroundStyle(.coachForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
      if sessions.count > Metrics.visibleCap {
        Text("+\(sessions.count - Metrics.visibleCap) more")
          .font(.coachText2xs)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
  }

  private enum Metrics {
    static let visibleCap = 4
    static let dayColumn: CGFloat = 26
  }
}

/// The stale/empty state: no current-Sofia-ISO-week plan mirrored (week rolled over, or nothing
/// cached yet) — never yesterday's week presented as current.
private struct WeeklyPlaceholder: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text("THIS WEEK")
        .font(.coachText2xs)
        .tracking(1)
        .foregroundStyle(.coachForegroundSubtle)
      Text("—")
        .font(.coachText3xl)
        .foregroundStyle(.coachForegroundSubtle)
      Text("No plan for this week yet")
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}
