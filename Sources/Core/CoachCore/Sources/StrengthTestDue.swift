import Dependencies
import Foundation

/// Whether a new strength test is due — the single rule the tab badge, the entry-row dot, and the
/// screen callout all derive from.
///
/// Due ⇔ there is **no** strength test logged in the current ISO week: either nothing has been logged
/// (`nil`), or the last test falls in an earlier ISO week than now. The week math (and its year-boundary
/// handling, e.g. a `yearForWeekOfYear` rollover) is delegated entirely to ``ISOWeek``, which reads the
/// injected `\.calendar` / `\.date` — so this helper inherits the same deterministic, Europe/Sofia-pinned
/// behavior and needs no explicit `calendar`/`now` parameters.
///
/// Takes a `Date?` rather than a `StrengthTest` so `CoachCore` stays below `DomainModels`; callers pass
/// `repository.current(now)?.date`.
public func isStrengthTestDue(lastTestDate: Date?) -> Bool {
  guard let last = lastTestDate else { return true }
  return ISOWeek.containing(last) != ISOWeek.current
}
