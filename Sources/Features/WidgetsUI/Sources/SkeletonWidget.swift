// The WidgetKit side of the skeleton widget (Phase 21.1): entry, provider, and the `Widget`
// conformance the extension's `@main` bundle lists. Whole file `#if canImport(WidgetKit)`-guarded so
// the macOS host build (`swift build`/`swift test`) degrades to an empty file if the module is
// missing. The provider reads via the `WidgetSnapshotClient` INTERFACE — the extension process links
// `WidgetSnapshotClientLive`, so the dynamic `liveValue` lookup resolves the real App Group store.

#if canImport(WidgetKit)
  import CoachCore
  import Dependencies
  import DesignSystem
  import SwiftUI
  import WidgetKit
  import WidgetSnapshotClient

  struct SkeletonEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
  }

  struct SkeletonProvider: TimelineProvider {
    func placeholder(in _: Context) -> SkeletonEntry {
      .fixture
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (SkeletonEntry) -> Void) {
      completion(.fixture)
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<SkeletonEntry>) -> Void) {
      @Dependency(\.widgetSnapshot) var widgetSnapshot
      Task {
        // `Date()`, not `@Dependency(\.date)`: the extension process runs no `prepareDependencies`.
        let now = Date()
        let snapshot = await widgetSnapshot.read()
        completion(Timeline(
          entries: [SkeletonEntry(date: now, snapshot: snapshot)],
          // One refresh entry at the next Sofia midnight — past it the entry renders stale.
          policy: .after(WidgetTimeline.nextSofiaMidnight(after: now))
        ))
      }
    }
  }

  extension SkeletonEntry {
    /// Gallery/placeholder fixture — static plausible values, never the real store.
    static var fixture: SkeletonEntry {
      SkeletonEntry(date: Date(), snapshot: nil)
    }
  }

  /// The pipeline-proof widget (kind string is throwaway — the real widgets in 21.2+ pick their own).
  public struct SkeletonWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
      StaticConfiguration(kind: "CoachSkeletonWidget", provider: SkeletonProvider()) { entry in
        SkeletonWidgetView(
          date: entry.snapshot?.daily?.date,
          readinessScore: entry.snapshot?.daily?.readiness.score,
          // Staleness display = the shared TASK-001 helper, never re-derived date math.
          isStale: entry.snapshot?.daily?.isCurrent(at: entry.date) != true
        )
        .widgetURL(CoachDeepLink.today.url)
        .containerBackground(.coachBackground, for: .widget)
      }
      .supportedFamilies([.systemSmall])
      .configurationDisplayName("Coach")
      .description("Snapshot pipeline proof — replaced by the real widgets.")
    }
  }
#endif
