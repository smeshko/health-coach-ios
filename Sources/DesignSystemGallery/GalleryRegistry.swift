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
    GalleryComponent(name: "DayBadge") { AnyView(DayBadgePage()) },
    GalleryComponent(name: "SegmentedBar") { AnyView(SegmentedBarPage()) },
    GalleryComponent(name: "BarColumns") { AnyView(BarColumnsPage()) },
  ]

  @MainActor static let composites: [GalleryComponent] = [
    GalleryComponent(name: "Chart") { AnyView(ChartGalleryPage()) },
  ]
}
