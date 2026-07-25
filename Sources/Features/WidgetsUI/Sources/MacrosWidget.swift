// The WidgetKit side of the daily-macros widget (Phase 21.3). Same shape as `SessionWidget.swift`:
// `#if canImport(WidgetKit)`-guarded, shared `DailyProvider`, rendering in the plain-SwiftUI
// `MacrosWidgetState`/`MacrosWidgetView`.

#if canImport(WidgetKit)
  import CoachCore
  import DesignSystem
  import SwiftUI
  import WidgetKit
  import WidgetSnapshotClient

  /// Today's fuel targets (day type, kcal/protein/carbs, medium adds fat + hydration) with
  /// yesterday's vs-target footer.
  public struct MacrosWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
      StaticConfiguration(kind: "CoachMacrosWidget", provider: DailyProvider()) { entry in
        MacrosWidgetFamilyView(entry: entry)
          .widgetURL(CoachDeepLink.today.url)
          .containerBackground(.coachBackground, for: .widget)
      }
      .supportedFamilies([.systemSmall, .systemMedium])
      // The layouts own their `spaceMd` padding — system margins would double it.
      .contentMarginsDisabled()
      .configurationDisplayName("Daily Fuel")
      .description("Today's macro targets and yesterday's recap.")
    }
  }

  /// Maps the ambient `widgetFamily` to the view's `Layout` and derives the state from the entry.
  struct MacrosWidgetFamilyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyEntry

    var body: some View {
      MacrosWidgetView(
        state: .make(daily: entry.daily, now: entry.date),
        layout: family == .systemMedium ? .medium : .small
      )
    }
  }
#endif
