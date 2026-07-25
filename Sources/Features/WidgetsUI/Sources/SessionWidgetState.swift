import CoachCore
import DesignSystem
import DomainModels
import Foundation
import WidgetSnapshotClient

/// The session widget's rendered state, derived once from the mirrored `daily` section (Phase 21.2).
/// Every branch is a dedicated layout — never an empty widget: a tripped safety gate and the rest
/// card each get their own state, and a missing/stale snapshot renders the stale placeholder instead
/// of presenting yesterday's session as current.
public enum SessionWidgetState: Equatable, Sendable {
  /// An active session — the athlete's selected block when one is stored for today, else the
  /// brief's planned session (`selectedSession ?? plannedSession`).
  case session(SessionBlock)
  /// The planned rest card (`card == .rest`, gate untripped).
  case rest
  /// A tripped safety gate — "Rest today" + the typed reasons.
  case gate([SafetyReason])
  /// No snapshot, or the snapshot's brief is not for `now`'s Sofia day.
  case stale

  /// The pure derivation every family renders from. Staleness = the shared 21.1 Sofia helper.
  public static func make(
    daily: WidgetDailySnapshot?, now: Date, calendar: Calendar = .europeSofia
  ) -> SessionWidgetState {
    guard let daily, daily.isCurrent(at: now, calendar: calendar) else { return .stale }
    if daily.safetyGate.triggered { return .gate(daily.safetyGate.reasons) }
    let block = daily.selectedSession ?? daily.plannedSession
    return block.isRest ? .rest : .session(block)
  }
}

public extension SessionWidgetState {
  /// The one-line lock-screen summary ("Easy Run · 40–50 min · Z2", or the gate reason).
  var summaryLine: String {
    switch self {
    case let .session(block):
      var parts = ["\(block.card.label) · \(block.durationText) min"]
      if let zone = block.zoneTarget { parts.append(zone.badgeLabel) }
      return parts.joined(separator: " · ")
    case .rest:
      return "Rest today"
    case let .gate(reasons):
      guard let first = reasons.first else { return "Rest today" }
      return "Rest today · \(first.label)"
    case .stale:
      return "Open Coach for today's brief"
    }
  }
}

extension SessionBlock {
  /// The duration window as the widget renders it — "40–50", collapsing to "45" on equal bounds.
  /// Derived from `durationRange` so an inverted brief renders normalized, never backwards.
  var durationText: String {
    let range = durationRange
    return range.lowerBound == range.upperBound
      ? "\(range.lowerBound)"
      : "\(range.lowerBound)–\(range.upperBound)"
  }
}

extension Zone {
  /// The compact badge form ("Z2").
  var badgeLabel: String { rawValue.uppercased() }
}
