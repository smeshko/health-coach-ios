import DesignSystem
import SwiftUI

/// TEMPORARY (Epic 5.5): the design-system gallery dev tool, rooted by `App` until Epic 06 restores the
/// real `AppView` shell. A navigable browser split into a **Design System** section (Colors / Typography
/// / Spacing & Radii / Icons), a **Primitives** section (one subpage per primitive, all states), and a
/// **Composites** section (components assembled from primitives, e.g. the Chart). The gallery's own
/// chrome is token-only — it should itself exemplify the system.
public struct DesignSystemGalleryView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      DesignSystemGalleryList()
    }
  }
}

/// The gallery's navigable list **without** an enclosing `NavigationStack`, so it can be pushed onto a
/// host stack (e.g. the DEBUG dev menu's) — its `NavigationLink`s then push onto whichever stack already
/// surrounds it. `DesignSystemGalleryView` wraps this in a stack for standalone presentation.
public struct DesignSystemGalleryList: View {
  public init() {}

  public var body: some View {
    List {
      Section("Design System") {
        NavigationLink("Colors") { ColorsGalleryPage() }
        NavigationLink("Typography") { TypographyGalleryPage() }
        NavigationLink("Spacing & Radii") { SpacingGalleryPage() }
        NavigationLink("Icons") { IconsGalleryPage() }
        NavigationLink("Labels") { LabelsGalleryPage() }
      }
      Section("Primitives") {
        ForEach(GalleryComponent.primitives) { component in
          NavigationLink(component.name) { component.page() }
        }
      }
      Section("Composites") {
        ForEach(GalleryComponent.composites) { component in
          NavigationLink(component.name) { component.page() }
        }
      }
    }
    .navigationTitle("Design System")
  }
}
