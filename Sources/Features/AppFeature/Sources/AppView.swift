import ComposableArchitecture
import DesignSystem
import OnboardingFeature
import SwiftUI

/// The app root view: an onboarding shell **or** the main tab bar, chosen by the store's `route` case,
/// with an app-colored launch overlay on top while the session is restoring (Phase 12.4, D1).
///
/// **Launch overlay (D1):** while `store.isRestoringSession`, an opaque `.coachBackground` frame (the same
/// color as the launch screen, TASK-001) covers the route, so the first *visible* frame after the launch
/// screen is already the resolved screen — no white flash, no MainTabs-then-onboarding (or reverse)
/// flicker. `._tokenChecked` clears the flag and the overlay crossfades out via the 12.2 `screenChange`
/// token. The route still mounts immediately underneath (happy-path-first; 12.1's D8 gates orchestration).
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
    ZStack {
      Group {
        if let store = store.scope(state: \.onboardingRoute, action: \.onboarding) {
          OnboardingView(store: store)
        } else if let store = store.scope(state: \.mainRoute, action: \.main) {
          MainTabsView(store: store)
        }
      }

      // The launch-restore overlay (D1): an opaque app-colored frame over the route until the token check
      // resolves, then it crossfades away — so nothing *visible* changes until the route is known.
      if store.isRestoringSession {
        Color.coachBackground
          .ignoresSafeArea()
          .transition(.opacity)
      }
    }
    .coachAnimation(.screenChange, value: store.isRestoringSession)
    .task {
      store.send(._appWillAppear)
      store.send(._restoreSession)
    }
    // `coachapp://` deep links (Phase 21.1) — on the same never-re-mounting outer container as the
    // lifecycle hook, so URL opens are received regardless of which route branch is showing.
    .onOpenURL { store.send(.deepLink($0)) }
  }
}
