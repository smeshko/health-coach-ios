// The WidgetKit side of the today's-session widget (Phase 21.2): family→layout mapping and the
// `Widget` conformance the extension's bundle lists. Guarded like SkeletonWidget PLUS `!os(macOS)`
// — the lock-screen accessory families are marked unavailable on macOS, so the host build must skip
// this file entirely; state derivation and rendering live in the plain-SwiftUI
// `SessionWidgetState`/`SessionWidgetView` so the snapshot target covers every family.

#if canImport(WidgetKit) && !os(macOS)
  import CoachCore
  import DesignSystem
  import SwiftUI
  import WidgetKit
  import WidgetSnapshotClient

  /// Today's session on the home screen (small/medium) and lock screen (inline/rectangular).
  public struct SessionWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
      StaticConfiguration(kind: "CoachSessionWidget", provider: DailyProvider()) { entry in
        SessionWidgetFamilyView(entry: entry)
          .widgetURL(CoachDeepLink.today.url)
          .containerBackground(.coachBackground, for: .widget)
      }
      .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
      // The home-screen layouts own their `spaceMd` padding — system margins would double it.
      .contentMarginsDisabled()
      .configurationDisplayName("Today's Session")
      .description("Today's planned session, or your selected alternative.")
    }
  }

  /// Maps the ambient `widgetFamily` to the view's `Layout` and derives the state from the entry.
  struct SessionWidgetFamilyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyEntry

    var body: some View {
      SessionWidgetView(state: .make(daily: entry.daily, now: entry.date), layout: layout)
    }

    private var layout: SessionWidgetView.Layout {
      switch family {
      case .systemMedium: .medium
      case .accessoryInline: .inline
      case .accessoryRectangular: .rectangular
      default: .small
      }
    }
  }
#endif
