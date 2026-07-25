// The WidgetKit side of the check-in nudge widget (Phase 21.5): entry, provider, and the `Widget`
// conformance the extension's `@main` bundle lists. Whole file `#if canImport(WidgetKit)`-guarded so
// the macOS host build degrades to an empty file. The provider reads via the `WidgetSnapshotClient`
// INTERFACE — the extension process links `WidgetSnapshotClientLive`, so the dynamic `liveValue`
// lookup resolves the real App Group store.

#if canImport(WidgetKit)
  import CoachCore
  import Dependencies
  import DesignSystem
  import SwiftUI
  import WidgetKit
  import WidgetSnapshotClient

  struct CheckInEntry: TimelineEntry {
    let date: Date
    let checkIn: WidgetCheckInState?
  }

  struct CheckInProvider: TimelineProvider {
    func placeholder(in _: Context) -> CheckInEntry {
      .fixture
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (CheckInEntry) -> Void) {
      completion(.fixture)
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<CheckInEntry>) -> Void) {
      @Dependency(\.widgetSnapshot) var widgetSnapshot
      Task {
        // `Date()`, not `@Dependency(\.date)`: the extension process runs no `prepareDependencies`.
        let now = Date()
        let snapshot = await widgetSnapshot.read()
        let midnight = WidgetTimeline.nextSofiaMidnight(after: now)
        completion(Timeline(
          entries: [
            CheckInEntry(date: now, checkIn: snapshot?.checkIn),
            // A second entry AT the rollover: its `date` is past the state's Sofia day, so the shared
            // staleness helper renders it unlogged the moment the day flips — the nudge reset doesn't
            // wait on WidgetKit re-running the provider.
            CheckInEntry(date: midnight, checkIn: snapshot?.checkIn),
          ],
          policy: .after(midnight)
        ))
      }
    }
  }

  extension CheckInEntry {
    /// Gallery/placeholder fixture — the unlogged nudge, never the real store.
    static var fixture: CheckInEntry {
      CheckInEntry(date: Date(), checkIn: nil)
    }
  }

  /// The interactive check-in nudge (epic Phase 21.5): quick-log an all-clear from the home screen,
  /// or tap through ("Symptoms…" / anywhere outside the button) into the app's check-in flow.
  public struct CheckInWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
      StaticConfiguration(kind: "CoachCheckInWidget", provider: CheckInProvider()) { entry in
        CheckInWidgetView(checkIn: entry.checkIn, now: entry.date)
          .widgetURL(CoachDeepLink.checkIn.url)
          .containerBackground(.coachBackground, for: .widget)
      }
      .supportedFamilies([.systemSmall])
      .configurationDisplayName("Check-in")
      .description("Log today's all-clear, or jump into the app for symptoms.")
    }
  }
#endif
