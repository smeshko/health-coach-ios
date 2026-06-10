import ComposableArchitecture
import DesignSystem
import SettingsFeature
import SwiftUI

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
      NavigationStack(path: $store.scope(state: \.today, action: \.today)) {
        TabRootPlaceholder(title: "Today", icon: Icon.today.systemName)
      } destination: { store in
        switch store.case {
        case .placeholder: PlaceholderDestinationView()
        }
      }
      .tabItem { Label("Today", systemImage: Icon.today.systemName) }
      .tag(MainTabs.Tab.today)

      NavigationStack(path: $store.scope(state: \.weekly, action: \.weekly)) {
        TabRootPlaceholder(title: "This Week", icon: Icon.week.systemName)
      } destination: { store in
        switch store.case {
        case .placeholder: PlaceholderDestinationView()
        }
      }
      .tabItem { Label("Week", systemImage: Icon.week.systemName) }
      .tag(MainTabs.Tab.weekly)

      NavigationStack(path: $store.scope(state: \.settings, action: \.settings)) {
        SettingsFeatureView(store: store.scope(state: \.settingsRoot, action: \.settingsRoot))
      } destination: { store in
        switch store.case {
        case .placeholder: PlaceholderDestinationView()
        }
      }
      .tabItem { Label("You", systemImage: Icon.you.systemName) }
      .tag(MainTabs.Tab.settings)
    }
    .tint(.coachAccent)
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

/// A pushed placeholder destination (the `*Path.placeholder` case).
private struct PlaceholderDestinationView: View {
  var body: some View {
    Text("Placeholder")
      .font(.coachTextLg)
      .foregroundStyle(.coachForeground)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)
  }
}
