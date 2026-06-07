import SwiftUI

/// The Components-section registry — every 5.2 primitive + 5.3/5.4 composite as one entry, each
/// linking to a subpage showing all of that component's documented states. Adding a component is one
/// entry here.
extension GalleryComponent {
  @MainActor static let all: [GalleryComponent] = [
    // Phase 5.2 primitives.
    GalleryComponent(name: "Buttons") { AnyView(ButtonsPage()) },
    GalleryComponent(name: "SegTabs") { AnyView(SegTabsPage()) },
    GalleryComponent(name: "Pill") { AnyView(PillPage()) },
    GalleryComponent(name: "Chip") { AnyView(ChipPage()) },
    GalleryComponent(name: "DayBadge") { AnyView(DayBadgePage()) },
    GalleryComponent(name: "Marker") { AnyView(MarkerPage()) },
    GalleryComponent(name: "ZoneBar") { AnyView(ZoneBarPage()) },
    GalleryComponent(name: "ReadinessBar") { AnyView(ReadinessBarPage()) },
    GalleryComponent(name: "PrehabAddon") { AnyView(PrehabAddonPage()) },
    GalleryComponent(name: "StatusBar") { AnyView(StatusBarPage()) },
    GalleryComponent(name: "TabBar") { AnyView(TabBarPage()) },
    GalleryComponent(name: "RestDay") { AnyView(RestDayPage()) },
    GalleryComponent(name: "MessageState") { AnyView(MessageStatePage()) },
    // Phase 5.3 / 5.4 composites.
    GalleryComponent(name: "SessionCard") { AnyView(SessionCardPage()) },
    GalleryComponent(name: "ZoneChip") { AnyView(ZoneChipPage()) },
    GalleryComponent(name: "FlagBadge") { AnyView(FlagBadgePage()) },
    GalleryComponent(name: "DayTypeTag") { AnyView(DayTypeTagPage()) },
    GalleryComponent(name: "ReadinessGauge") { AnyView(ReadinessGaugePage()) },
    GalleryComponent(name: "NutritionPanel") { AnyView(NutritionPanelPage()) },
    GalleryComponent(name: "MacroRow") { AnyView(MacroRowPage()) },
    GalleryComponent(name: "NarrativeRenderer") { AnyView(NarrativeRendererPage()) },
  ]
}
