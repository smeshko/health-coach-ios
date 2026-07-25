import CoachCore
import ComposableArchitecture
import LocalRepositories
import SettingsFeature
import StrengthTestFeature
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
    /// Whether a new strength test is due — drives the You-tab badge. `MainTabs` is the **single
    /// deriver** (DECISIONS #2): it reads the repository on a lifecycle hook + scene-active and writes
    /// this flag plus `settingsRoot.strengthTestDue` (the row dot), so the rule lives in one place.
    public var strengthTestDue: Bool = false
    public init() {}
  }

  public enum Action {
    case tabSelected(Tab)
    /// Re-derive the strength-test due state (the TabView lifecycle hook + scene re-activation).
    case refreshDue
    case dueRefreshed(Bool)
    case todayRoot(TodayFeature.Action)
    case weeklyRoot(WeeklyFeature.Action)
    case weekly(StackAction<WeeklyPath.State, WeeklyPath.Action>)
    case settings(StackAction<SettingsPath.State, SettingsPath.Action>)
    case settingsRoot(SettingsFeature.Action)
    case delegate(Delegate)
  }

  @Dependency(\.strengthTestRepository) var strengthTestRepository
  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.date) var date

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

      case .refreshDue:
        // Read the latest test and derive the due flag (the single rule, TASK-001). `isStrengthTestDue`
        // reads the ambient `\.calendar`/`\.date` itself, so the effect needs no extra args.
        // The same launch/foreground hook drains the widget check-in inbox (Phase 21.5) — a merged
        // sibling effect so the badge derivation never waits on the DB drain. Failures drop quietly:
        // the inbox file survives, so the next activation retries.
        return .merge(
          .run { [checkInRepository] _ in
            try? await checkInRepository.drainWidgetInbox()
          },
          .run { [strengthTestRepository, now = date.now] send in
            let test = try? await strengthTestRepository.current(now)
            await send(.dueRefreshed(isStrengthTestDue(lastTestDate: test?.date)))
          }
        )

      case let .dueRefreshed(isDue):
        // Write both sinks from the one derivation: the You-tab badge + the Settings row dot.
        state.strengthTestDue = isDue
        state.settingsRoot.strengthTestDue = isDue
        return .none

      case .settingsRoot(.delegate(.openStrengthTest)):
        // The Strength-test row asked to open the screen → push it onto the You-tab stack. De-dupe a
        // double-tap (review round-2 #1): two stacked editors let a save on the popped-to stale duplicate
        // overwrite the fresh counts (day/latest-wins upsert). Mirrors the deep-link guard in AppFeature.
        if case .strengthTest? = state.settings.last { return .none }
        state.settings.append(.strengthTest(StrengthTestFeature.State()))
        return .none

      case let .settings(.element(id: id, action: .strengthTest(.delegate(.saved)))):
        // A test was saved → pop the screen and clear both due flags. This is the single place that owns
        // the pop + clear (it converges with the deep-link push in TASK-006 on the same stack).
        state.settings.pop(from: id)
        state.strengthTestDue = false
        state.settingsRoot.strengthTestDue = false
        return .none

      case .settingsRoot(.delegate(.tokenReset)):
        // The You-tab root asked to clear the session (the DEBUG dev menu's reset, or Phase 10.2's
        // Disconnect row) → bubble up to `AppFeature`, which swaps `.main → .onboarding` (navigation
        // lives at the root — D7).
        return .send(.delegate(.tokenReset))
      case .todayRoot, .weeklyRoot, .weekly, .settings, .settingsRoot, .delegate:
        // The `.forEach`s below own the stack plumbing. `todayRoot` (Epic 8) and `weeklyRoot` (Epic 9)
        // each own their own load/orchestration — `MainTabs` just composes their reducers.
        return .none
      }
    }
    .forEach(\.weekly, action: \.weekly)
    .forEach(\.settings, action: \.settings)
  }
}
