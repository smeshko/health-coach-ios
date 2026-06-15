import ComposableArchitecture
import SettingsFeature
import TodayFeature
import WeeklyFeature

/// The tab-root reducer (the `.main` branch of `AppFeature`). Holds the selected tab, the Today-tab
/// **root** (`TodayFeature`, Epic 8) and the You-tab **root** (`SettingsFeature`), plus the Week/You
/// `StackState` drill-downs driven by `.forEach` (caseless until Epics 9/10 fill them). The
/// You/Settings tab root is filled minimally by Phase 7.4 (the DEBUG dev menu) and expanded by 10.2.
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
    public var weekly = StackState<WeeklyPath.State>()
    public var settings = StackState<SettingsPath.State>()
    /// The Today-tab root feature. The hero daily-brief screen (Epic 8); replaces 6.1's
    /// `TabRootPlaceholder` so each Today phase is testable as it lands.
    public var todayRoot = TodayFeature.State()
    /// The Week-tab root feature (Epic 9). The menu-with-budgets "This Week" screen; replaces 6.1's
    /// `TabRootPlaceholder`. (`weekly` above is the drill-down `StackState`, left as-is — D7/§10 out of scope.)
    public var weeklyRoot = WeeklyFeature.State()
    /// The You-tab root feature (rendered above the `settings` drill-down stack). Minimal in Phase 7.4.
    public var settingsRoot = SettingsFeature.State()
    public init() {}
  }

  public enum Action {
    case tabSelected(Tab)
    case todayRoot(TodayFeature.Action)
    case weeklyRoot(WeeklyFeature.Action)
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
    Scope(state: \.weeklyRoot, action: \.weeklyRoot) {
      WeeklyFeature()
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
      case .todayRoot, .weeklyRoot, .weekly, .settings, .settingsRoot, .delegate:
        // You destinations land in Epic 10; the `.forEach`s below own the stack plumbing. `todayRoot`
        // (Epic 8) and `weeklyRoot` (Epic 9) each own their own load/orchestration — `MainTabs` just
        // composes their reducers.
        return .none
      }
    }
    .forEach(\.weekly, action: \.weekly)
    .forEach(\.settings, action: \.settings)
  }
}
