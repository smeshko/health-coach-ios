import ComposableArchitecture
import DesignSystem
import SettingsFeature
import SwiftUI
import TodayFeature

/// The main tab bar (the `.main` branch). Three tabs — **Today / Week / You** — each its own
/// `NavigationStack` bound to an independent per-tab `StackState`. Tab roots and pushed destinations are
/// placeholders in Phase 7.1 (real screens land in Epics 8/9/10; the You tab root is filled by 7.4).
struct MainTabsView: View {
  @Bindable var store: StoreOf<MainTabs>

  var body: some View {
    TabView(
      selection: Binding(
        get: { store.selectedTab },
        set: { store.send(.tabSelected($0)) }
      )
    ) {
      NavigationStack {
        TodayView(store: store.scope(state: \.todayRoot, action: \.todayRoot))
      }
      .tabItem { Label("Today", systemImage: Icon.today.systemName) }
      .tag(MainTabs.Tab.today)

      // Week / You destinations are caseless until Epics 9/10; the `EmptyView` arm is unreachable
      // (the destination store is uninhabited) and exists only to type the closure.
      NavigationStack(path: $store.scope(state: \.weekly, action: \.weekly)) {
        TabRootPlaceholder(title: "This Week", icon: Icon.week.systemName)
      } destination: { _ in
        EmptyView()
      }
      .tabItem { Label("Week", systemImage: Icon.week.systemName) }
      .tag(MainTabs.Tab.weekly)

      NavigationStack(path: $store.scope(state: \.settings, action: \.settings)) {
        SettingsFeatureView(store: store.scope(state: \.settingsRoot, action: \.settingsRoot))
      } destination: { _ in
        EmptyView()
      }
      .tabItem { Label("You", systemImage: Icon.you.systemName) }
      .tag(MainTabs.Tab.settings)
    }
    .tint(.coachAccent)
    // The Today cache-first open is dispatched from the AppFeature reducer (Phase 12.1, DECISIONS D8) —
    // the `._tokenChecked(hasToken: true)` staying-put branch (cold launch with a token) and the
    // `.onboarding(.delegate(.connected))` post-connect swap. A token-less launch therefore never
    // hydrates cached health content before the onboarding swap. No view `.task` here.
  }
}

/// A centered placeholder for a tab's root screen (real content arrives with the tab's epic).
private struct TabRootPlaceholder: View {
  let title: String
  let icon: String

  var body: some View {
    VStack(spacing: CoachSpacing.spaceSm) {
      Image(systemName: icon)
        .font(.system(size: 40))
        .foregroundStyle(.coachAccent)
      Text(title)
        .font(.coachTextXl)
        .foregroundStyle(.coachForeground)
      Text("Coming soon")
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.coachBackground)
    .navigationTitle(title)
  }
}
