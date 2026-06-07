import AppFeature
import ComposableArchitecture
import DesignSystemGallery
import SwiftUI

@main
struct CoachApp: App {
  var body: some Scene {
    WindowGroup {
      // TEMP (Epic 5.5): the design-system gallery is the app root until Epic 06 restores the real
      // shell. To restore, swap the next line back to the commented `AppView(...)` line below.
      DesignSystemGalleryView()
      // AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
    }
  }
}
