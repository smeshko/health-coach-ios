import ComposableArchitecture
import OnboardingFeature
import SwiftUI

/// The app root view: an onboarding shell **or** the main tab bar, chosen by the store's enum case.
///
/// The `.task` lifecycle hook lives on the single outer container that wraps the branch switch and does
/// **not** re-mount when the case swaps — so `._appWillAppear` (open the session stream) and
/// `._restoreSession` (the launch token check that may fall back to onboarding) each fire exactly once
/// per process and the single-subscriber session stream is never re-iterated on an onboarding↔main swap
/// (TASK-002's once-per-process requirement). Never move it inside a branch.
public struct AppView: View {
  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if let store = store.scope(state: \.onboarding, action: \.onboarding) {
        OnboardingView(store: store)
      } else if let store = store.scope(state: \.main, action: \.main) {
        MainTabsView(store: store)
      }
    }
    .task {
      store.send(._appWillAppear)
      store.send(._restoreSession)
    }
  }
}
