import SwiftUI

/// One Components-section entry — a name + a subpage builder — so the index list and the routing are
/// driven by one source and adding a component is a single entry. `GalleryComponent.all` is the
/// registry (populated in TASK-003).
struct GalleryComponent: Identifiable {
  var id: String { name }
  let name: String
  let page: @MainActor () -> AnyView
}
