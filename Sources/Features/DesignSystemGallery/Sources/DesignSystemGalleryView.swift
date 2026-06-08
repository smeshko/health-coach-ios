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
      List {
        Section("Design System") {
          NavigationLink("Colors") { ColorsGalleryPage() }
          NavigationLink("Typography") { TypographyGalleryPage() }
          NavigationLink("Spacing & Radii") { SpacingGalleryPage() }
          NavigationLink("Icons") { IconsGalleryPage() }
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
}
