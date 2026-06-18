import ComposableArchitecture
import DesignSystem
import SettingsFeature
import StrengthTestFeature
import SwiftUI
import TodayFeature
import WeeklyFeature

/// The main tab bar (the `.main` branch). Three tabs — **Today / Week / You** — each its own
/// `NavigationStack` bound to an independent per-tab `StackState`. Tab roots and pushed destinations are
/// placeholders in Phase 7.1 (real screens land in Epics 8/9/10; the You tab root is filled by 7.4).
struct MainTabsView: View {
  @Bindable var store: StoreOf<MainTabs>
  @Environment(\.scenePhase) private var scenePhase

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

      // Week (Epic 9): the real `WeeklyView` root, loading its own weekly plan on tab appear (`.task`
      // → the feature's `task` action — no AppFeature orchestration; the §11 chain stays Epic 07/08
      // work). The drill-down `weekly` stack is caseless until later; the `EmptyView` arm is unreachable.
      NavigationStack(path: $store.scope(state: \.weekly, action: \.weekly)) {
        WeeklyView(store: store.scope(state: \.weeklyRoot, action: \.weeklyRoot))
          .task { store.send(.weeklyRoot(.task)) }
      } destination: { _ in
        EmptyView()
      }
      .tabItem { Label("Week", systemImage: Icon.week.systemName) }
      .tag(MainTabs.Tab.weekly)

      NavigationStack(path: $store.scope(state: \.settings, action: \.settings)) {
        SettingsFeatureView(store: store.scope(state: \.settingsRoot, action: \.settingsRoot))
      } destination: { store in
        switch store.case {
        case let .strengthTest(strengthStore):
          StrengthTestView(store: strengthStore)
        }
      }
      .tabItem { Label("You", systemImage: Icon.you.systemName) }
      // A due strength test badges the You tab so the prompt is visible without first opening the tab
      // (DECISIONS #2). A count of 0 renders no badge.
      .badge(store.strengthTestDue ? 1 : 0)
      .tag(MainTabs.Tab.settings)
    }
    .tint(.coachAccent)
    // The Today cache-first open is dispatched from the AppFeature reducer (Phase 12.1, DECISIONS D8) —
    // the `._tokenChecked(hasToken: true)` staying-put branch (cold launch with a token) and the
    // `.onboarding(.delegate(.connected))` post-connect swap. A token-less launch therefore never
    // hydrates cached health content before the onboarding swap.
    //
    // The strength-test due badge IS derived at this always-alive level (DECISIONS #2) — on first appear
    // and on every scene re-activation, so a test logged elsewhere (or a new ISO week) reflects on return.
    .task { store.send(.refreshDue) }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active { store.send(.refreshDue) }
    }
  }
}
