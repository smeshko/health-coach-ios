import ComposableArchitecture
import SettingsFeature
import TodayFeature

/// The tab-root reducer (the `.main` branch of `AppFeature`). Holds the selected tab plus three
/// **independent** `StackState` drill-downs — one per tab — driven by `.forEach`, plus the You-tab
/// **root** (`SettingsFeature`). Tab/stack contents are placeholders in Phase 7.1: Today is Epic 8, Week
/// is Epic 9; the You/Settings tab root is filled minimally by Phase 7.4 (the DEBUG dev menu) and
/// expanded by Phase 10.2.
@Reducer
public struct MainTabs {
  /// The three tabs. The third is **labelled "You"** (person icon) in the view but keeps the internal
  /// name `settings` (its screen title stays "Settings"). There is no Trends tab — the design's
  /// four-tab bar is reconciled to three here (deferred design-drift).
  public enum Tab: Equatable { case today, weekly, settings }

  /// Delegate actions `AppFeature` listens for. `tokenReset` (bubbled up from the You-tab root) asks the
  /// app root to clear the session and swap `.main → .onboarding`.
  public enum Delegate: Equatable {
    case tokenReset
  }

  @ObservableState
  public struct State: Equatable {
    public var selectedTab: Tab = .today
    public var today = StackState<TodayPath.State>()
    public var weekly = StackState<WeeklyPath.State>()
    public var settings = StackState<SettingsPath.State>()
    /// The Today-tab root feature (rendered above the `today` drill-down stack). The hero daily-brief
    /// screen (Epic 8); replaces 6.1's `TabRootPlaceholder` so each Today phase is testable as it lands.
    public var todayRoot = TodayFeature.State()
    /// The You-tab root feature (rendered above the `settings` drill-down stack). Minimal in Phase 7.4.
    public var settingsRoot = SettingsFeature.State()
    public init() {}
  }

  public enum Action {
    case tabSelected(Tab)
    case today(StackAction<TodayPath.State, TodayPath.Action>)
    case todayRoot(TodayFeature.Action)
    case weekly(StackAction<WeeklyPath.State, WeeklyPath.Action>)
    case settings(StackAction<SettingsPath.State, SettingsPath.Action>)
    case settingsRoot(SettingsFeature.Action)
    case delegate(Delegate)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.todayRoot, action: \.todayRoot) {
      TodayFeature()
    }
    Scope(state: \.settingsRoot, action: \.settingsRoot) {
      SettingsFeature()
    }
    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none
      case .settingsRoot(.delegate(.tokenReset)):
        // The You-tab root asked to clear the session (the DEBUG dev menu's reset, or Phase 10.2's
        // Disconnect row) → bubble up to `AppFeature`, which swaps `.main → .onboarding` (navigation
        // lives at the root — D7).
        return .send(.delegate(.tokenReset))
      case .today, .todayRoot, .weekly, .settings, .settingsRoot, .delegate:
        // Destinations land in Epics 8/9/10; the `.forEach`s below own the stack plumbing. `todayRoot`
        // (the Today screen, Epic 8) owns its own orchestration — `MainTabs` just composes its reducer.
        return .none
      }
    }
    .forEach(\.today, action: \.today)
    .forEach(\.weekly, action: \.weekly)
    .forEach(\.settings, action: \.settings)
  }
}
