import CoachCore
import DomainModels
import Foundation
import WidgetSnapshotClient

/// The macros widget's rendered state (Phase 21.3): today's `MacroFocus` plus yesterday's
/// vs-target recap when the brief carried one, or the stale placeholder past Sofia midnight —
/// the same staleness rule as the session widget (the shared 21.1 helper).
public enum MacrosWidgetState: Equatable, Sendable {
  /// Today's targets; `yesterday` is `intakeYesterday.vsTarget` (`nil` = no logged intake — the
  /// footer collapses, never zeros).
  case macros(MacroFocus, yesterday: IntakeVsTarget?)
  /// No snapshot, or the snapshot's brief is not for `now`'s Sofia day.
  case stale

  /// The pure derivation both families render from.
  public static func make(
    daily: WidgetDailySnapshot?, now: Date, calendar: Calendar = .europeSofia
  ) -> MacrosWidgetState {
    guard let daily, daily.isCurrent(at: now, calendar: calendar) else { return .stale }
    return .macros(daily.macroFocus, yesterday: daily.intakeYesterday?.vsTarget)
  }
}
