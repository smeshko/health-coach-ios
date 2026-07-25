// The WidgetKit side of the weekly-overview widget (Phase 21.4): entry, provider, and the `Widget`
// conformance the extension's `@main` bundle lists. Whole file `#if canImport(WidgetKit)`-guarded so
// the macOS host build degrades to an empty file. The provider reads via the `WidgetSnapshotClient`
// INTERFACE — the extension process links `WidgetSnapshotClientLive`, so the dynamic `liveValue`
// lookup resolves the real App Group store.

#if canImport(WidgetKit)
  import CoachCore
  import Dependencies
  import DesignSystem
  import DomainModels
  import SwiftUI
  import WidgetKit
  import WidgetSnapshotClient

  struct WeeklyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
  }

  struct WeeklyProvider: TimelineProvider {
    func placeholder(in _: Context) -> WeeklyEntry {
      .fixture
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (WeeklyEntry) -> Void) {
      completion(.fixture)
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<WeeklyEntry>) -> Void) {
      @Dependency(\.widgetSnapshot) var widgetSnapshot
      Task {
        // `Date()`, not `@Dependency(\.date)`: the extension process runs no `prepareDependencies`.
        let now = Date()
        let snapshot = await widgetSnapshot.read()
        completion(Timeline(
          entries: [WeeklyEntry(date: now, snapshot: snapshot)],
          // One refresh entry at the next Sofia midnight (the shared daily cadence) — the ISO-week
          // staleness check re-runs on each render, so the Monday rollover flips the entry stale.
          policy: .after(WidgetTimeline.nextSofiaMidnight(after: now))
        ))
      }
    }
  }

  extension WeeklyEntry {
    /// Gallery/placeholder fixture — static plausible values keyed to the CURRENT Sofia ISO week (so
    /// the gallery preview renders populated, not stale), never the real store.
    static var fixture: WeeklyEntry {
      let now = Date()
      let components = Calendar.europeSofia.dateComponents(
        [.yearForWeekOfYear, .weekOfYear], from: now
      )
      let isoWeek = String(
        format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0
      )
      return WeeklyEntry(
        date: now,
        snapshot: WidgetSnapshot(
          generatedAt: now,
          weekly: WidgetWeeklySnapshot(
            isoWeek: isoWeek,
            budgets: WeeklyBudgets(hardDays: 2, strengthSessions: 3, longRunKm: 14, deload: false),
            targets: WeeklyTargets(
              totalRunKm: 30, easyRunRatio: 0.8, strengthSessions: 3, hardDays: 2, cadenceSpm: 170
            ),
            coreSessions: [
              PlannedSession(
                card: .longRun, tier: .core, intensity: .easy, isHardDay: false, suggestedDay: .sat
              ),
              PlannedSession(
                card: .threshold, tier: .core, intensity: .quality, isHardDay: true, suggestedDay: .tue
              ),
              PlannedSession(
                card: .strengthLower, tier: .core, intensity: .quality, isHardDay: false,
                suggestedDay: .thu
              ),
            ]
          )
        )
      )
    }
  }

  /// The plan-only weekly overview (epic 21.4): budgets, key targets, and core sessions — no
  /// used-vs-budget progress, ever.
  public struct WeeklyWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
      StaticConfiguration(kind: "CoachWeeklyWidget", provider: WeeklyProvider()) { entry in
        WeeklyWidgetView(
          weekly: entry.snapshot?.weekly,
          // Staleness display = the shared TASK-001 helper, never re-derived date math.
          isStale: entry.snapshot?.weekly?.isCurrent(at: entry.date) != true
        )
        .widgetURL(CoachDeepLink.weekly.url)
        .containerBackground(.coachBackground, for: .widget)
      }
      .supportedFamilies([.systemMedium])
      .configurationDisplayName("This Week")
      .description("The week's plan — budgets, targets, and core sessions.")
    }
  }
#endif
