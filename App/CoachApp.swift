import AppFeature
import ComposableArchitecture
import SwiftUI

@main
struct CoachApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
    }
  }
}
