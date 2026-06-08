import ComposableArchitecture
import SwiftUI

public struct AppView: View {
  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    // Phase 7.1 TASK-001 scaffold — TASK-003 renders the real onboarding shell + tab bar and attaches
    // the once-per-process `._appWillAppear` lifecycle hook.
    Group {
      if store.scope(state: \.onboarding, action: \.onboarding) != nil {
        Text("Onboarding")
      } else {
        Text("Main")
      }
    }
  }
}
