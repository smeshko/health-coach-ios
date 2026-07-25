// The shared daily timeline entry + provider (Phases 21.2/21.3): both daily widgets render the
// snapshot's `daily` section on the same one-entry timeline that refreshes at the next Sofia
// midnight — past it the entry date flips the state derivations stale. `#if canImport(WidgetKit)`
// so the macOS host build degrades to an empty file (the SkeletonWidget convention).

#if canImport(WidgetKit)
  import CoachCore
  import Dependencies
  import DomainModels
  import WidgetKit
  import WidgetSnapshotClient

  struct DailyEntry: TimelineEntry {
    let date: Date
    let daily: WidgetDailySnapshot?
  }

  struct DailyProvider: TimelineProvider {
    func placeholder(in _: Context) -> DailyEntry {
      .fixture
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (DailyEntry) -> Void) {
      completion(.fixture)
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<DailyEntry>) -> Void) {
      @Dependency(\.widgetSnapshot) var widgetSnapshot
      Task {
        // `Date()`, not `@Dependency(\.date)`: the extension process runs no `prepareDependencies`.
        let now = Date()
        let snapshot = await widgetSnapshot.read()
        completion(Timeline(
          entries: [DailyEntry(date: now, daily: snapshot?.daily)],
          // One refresh entry at the next Sofia midnight — past it the entry renders stale.
          policy: .after(WidgetTimeline.nextSofiaMidnight(after: now))
        ))
      }
    }
  }

  extension DailyEntry {
    /// Gallery/placeholder fixture — static plausible values, never the real store. `date` matches
    /// the daily's day so the gallery shows the populated states, not the stale placeholder.
    static var fixture: DailyEntry {
      let now = Date()
      return DailyEntry(
        date: now,
        daily: WidgetDailySnapshot(
          date: now,
          readiness: Readiness(score: 82, band: .green),
          safetyGate: SafetyGate(triggered: false),
          plannedSession: SessionBlock(
            card: .easyRun, intensity: .easy, zoneTarget: .z2,
            durationMinLow: 40, durationMinHigh: 50
          ),
          macroFocus: MacroFocus(
            dayType: .moderate, caloriesKcal: 2400, proteinG: 150, carbsG: 280,
            fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0
          )
        )
      )
    }
  }
#endif
