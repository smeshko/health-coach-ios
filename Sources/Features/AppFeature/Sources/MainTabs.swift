import ComposableArchitecture

/// The tab-root reducer (the `.main` branch of `AppFeature`). Holds the selected tab plus three
/// **independent** `StackState` drill-downs — one per tab — driven by `.forEach`. Tab/stack contents
/// are placeholders in Phase 7.1: Today is Epic 8, Week is Epic 9, the You/Settings tab root is filled
/// minimally by Phase 7.4 and expanded by Phase 10.2.
@Reducer
public struct MainTabs {
  /// The three tabs. The third is **labelled "You"** (person icon) in the view but keeps the internal
  /// name `settings` (its screen title stays "Settings"). There is no Trends tab — the design's
  /// four-tab bar is reconciled to three here (deferred design-drift).
  public enum Tab: Equatable { case today, weekly, settings }

  @ObservableState
  public struct State: Equatable {
    public var selectedTab: Tab = .today
    public var today = StackState<TodayPath.State>()
    public var weekly = StackState<WeeklyPath.State>()
    public var settings = StackState<SettingsPath.State>()
    public init() {}
  }

  public enum Action {
    case tabSelected(Tab)
    case today(StackAction<TodayPath.State, TodayPath.Action>)
    case weekly(StackAction<WeeklyPath.State, WeeklyPath.Action>)
    case settings(StackAction<SettingsPath.State, SettingsPath.Action>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none
      case .today, .weekly, .settings:
        // Destinations land in Epics 8/9/10; the `.forEach`s below own the stack plumbing.
        return .none
      }
    }
    .forEach(\.today, action: \.today)
    .forEach(\.weekly, action: \.weekly)
    .forEach(\.settings, action: \.settings)
  }
}
