import CoachCore
import DomainModels
import Foundation

/// Shared Sofia timeline/staleness helpers for every widget's provider (DECISIONS D3). All take an
/// explicit `Calendar` (defaulting `.europeSofia`) instead of `@Dependency(\.calendar)` /
/// `ISOWeek.current` — the extension process never runs `prepareDependencies`, so the ambient
/// dependency there would silently be the device calendar, not Europe/Sofia.
public enum WidgetTimeline {
  /// The start of the NEXT Sofia day after `date` — the timeline-entry refresh instant. For a `date`
  /// exactly at Sofia midnight this is the FOLLOWING midnight.
  public static func nextSofiaMidnight(after date: Date, calendar: Calendar = .europeSofia) -> Date {
    let startOfDay = calendar.startOfDay(for: date)
    // Fallback is unreachable for the fixed Gregorian/ISO calendars in use; kept to avoid a trap.
    return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
  }
}

public extension WidgetDailySnapshot {
  /// Whether this snapshot's brief is for the same Sofia calendar day as `now` (mirrors the
  /// `sofiaToday()` `startOfDay` cache key, SyncGate.swift). Past Sofia midnight with no fresh brief
  /// this flips false and the widget shows its stale state instead of yesterday's session.
  func isCurrent(at now: Date, calendar: Calendar = .europeSofia) -> Bool {
    calendar.isDate(date, inSameDayAs: now)
  }
}

public extension WidgetCheckInState {
  /// Whether this check-in state refers to the same Sofia calendar day as `now` (mirror of the daily
  /// helper). Past Sofia midnight a logged state stops counting — the widget's nudge resets to
  /// unlogged at the day rollover (Phase 21.5).
  func isCurrent(at now: Date, calendar: Calendar = .europeSofia) -> Bool {
    calendar.isDate(date, inSameDayAs: now)
  }
}

public extension WidgetWeeklySnapshot {
  /// Whether `isoWeek` is `now`'s ISO week. Formats `now` with the same `"%04d-W%02d"` pattern as
  /// `BriefRepositoryLive.isoWeekKey` (module-internal there, so the 3-line formatter is duplicated
  /// here by design — keep the two in sync) and compares strings.
  func isCurrent(at now: Date, calendar: Calendar = .europeSofia) -> Bool {
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
    let key = String(
      format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0
    )
    return isoWeek == key
  }
}
