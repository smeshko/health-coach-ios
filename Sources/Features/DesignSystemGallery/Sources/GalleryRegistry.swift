import SwiftUI

/// The section registries — each entry links to a subpage showing all of that component's documented
/// states. Adding a component is one entry here.
///
/// - `primitives` — the single-purpose building blocks from the Primitives reference.
/// - `composites` — components assembled from primitives (e.g. a chart = `BarColumns` + labels).
extension GalleryComponent {
  @MainActor static let primitives: [GalleryComponent] = [
    GalleryComponent(name: "Buttons") { AnyView(ButtonsPage()) },
    GalleryComponent(name: "SegTabs") { AnyView(SegTabsPage()) },
    GalleryComponent(name: "Pill") { AnyView(PillPage()) },
    GalleryComponent(name: "Chip") { AnyView(ChipPage()) },
    GalleryComponent(name: "Banner") { AnyView(BannerPage()) },
    GalleryComponent(name: "InsetCallout") { AnyView(InsetCalloutPage()) },
    GalleryComponent(name: "DayBadge") { AnyView(DayBadgePage()) },
    GalleryComponent(name: "IconBadge") { AnyView(IconBadgePage()) },
    GalleryComponent(name: "SegmentedBar") { AnyView(SegmentedBarPage()) },
    GalleryComponent(name: "BarColumns") { AnyView(BarColumnsPage()) },
    GalleryComponent(name: "MacroDonut") { AnyView(MacroDonutPage()) },
    GalleryComponent(name: "Check-in controls") { AnyView(CheckInControlsPage()) },
  ]

  @MainActor static let composites: [GalleryComponent] = [
    GalleryComponent(name: "Chart") { AnyView(ChartGalleryPage()) },
    GalleryComponent(name: "Narrative") { AnyView(NarrativePage()) },
    GalleryComponent(name: "NutritionGauge") { AnyView(NutritionGaugePage()) },
    GalleryComponent(name: "SessionCard") { AnyView(SessionCardPage()) },
    GalleryComponent(name: "WeeklySessionRow") { AnyView(WeeklySessionRowPage()) },
    GalleryComponent(name: "SyncProgress") { AnyView(SyncProgressPage()) },
  ]
}
