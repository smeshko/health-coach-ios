import DesignSystem
import SwiftUI

/// TEMPORARY (Epic 5.5): the design-system gallery dev tool, rooted by `App` until Epic 06 restores the
/// real `AppView` shell. A navigable browser split into a **Design System** section (Colors / Typography
/// / Icons) and a **Components** section (one subpage per component, all states). The gallery's own
/// chrome is token-only — it should itself exemplify the system.
public struct DesignSystemGalleryView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      List {
        Section("Design System") {
          NavigationLink("Colors") { ColorsGalleryPage() }
          NavigationLink("Typography") { TypographyGalleryPage() }
          NavigationLink("Icons") { IconsGalleryPage() }
        }
        Section("Components") {
          ForEach(GalleryComponent.all) { component in
            NavigationLink(component.name) { component.page() }
          }
        }
      }
      .navigationTitle("Design System")
    }
  }
}
