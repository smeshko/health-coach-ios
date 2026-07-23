#if DEBUG
  import ComposableArchitecture
  import DevSettings
  import LogClient
  import SampleData
  import TokenClient

  /// The DEBUG dev menu (ARCHITECTURE §7.1 / D25). It mirrors the `useMockData` flag, the
  /// per-`DevEndpoint` `SampleScenario` map, and the per-`LogCategory` enabled flags from
  /// `@Dependency(\.devSettings)` and writes every change straight back through the `DevSettings`
  /// writers, so the next `*.routed(dev:)` repository call (or the next log) reflects it with **no
  /// relaunch** (the per-call read is Phase 4.1's contract, not this menu's). `resetTokenTapped` clears
  /// the bearer token via `@Dependency(\.tokenClient)` and bubbles a `tokenReset` delegate so the shell
  /// restarts onboarding — re-testing the connect flow on demand.
  ///
  /// The whole surface is `#if DEBUG`, so it compiles out of RELEASE (D25: routing collapses to `.live`).
  /// It touches only the `DevSettings` + `TokenClient` + `LogClient` **interfaces** (the app-spine
  /// carve-out, §3) — no repository call, no `*Live`, no DTO/GRDB/HealthKit. The `LogClient` import is
  /// only for the `LogCategory` vocabulary; the toggles are written through the `DevSettings` log seam
  /// (keyed by `rawValue`, so `DevSettings` itself never imports `LogClient` — app-logging DECISIONS 3).
  @Reducer
  public struct DevMenuFeature {
    /// Delegate actions the parent (`SettingsFeature`) listens for.
    public enum Delegate: Equatable {
      /// The bearer token was cleared — the parent routes the app back to onboarding (the connect flow).
      case tokenReset
      /// "Force full re-sync" was tapped — the parent clears the sync watermark anchor via
      /// `SyncRepository.resetWatermark` (the menu itself stays repository-free, D25's app-spine
      /// carve-out), so the next sync re-exports the whole history from the backfill floor.
      case fullResyncRequested
    }

    @ObservableState
    public struct State: Equatable {
      /// Whether repositories route to their `.mock(scenario:)` value. Mirrors `dev.useMockData()`.
      public var useMockData = false
      /// The selected scenario per endpoint. Mirrors `dev.scenario(_:)` over `DevEndpoint.allCases`.
      public var scenarios: [DevEndpoint: SampleScenario] = [:]
      /// Whether each verbose log category is enabled. Mirrors `dev.isLogCategoryEnabled(_:)` over
      /// `LogCategory.allCases`; always-on categories (`.http`) are seeded `true` and never written.
      public var logEnabled: [LogCategory: Bool] = [:]
      /// The pushed log-viewer screen (LOGGING → "View logs"), `nil` when not presented.
      @Presents public var logViewer: LogViewerFeature.State?
      public init() {}
    }

    public enum Action: Equatable {
      case onAppear
      case useMockDataToggled(Bool)
      case scenarioSelected(SampleScenario, DevEndpoint)
      case logCategoryToggled(LogCategory, Bool)
      case viewLogsTapped
      case logViewer(PresentationAction<LogViewerFeature.Action>)
      case resetTokenTapped
      case forceFullResyncTapped
      case delegate(Delegate)
    }

    @Dependency(\.devSettings) var dev
    @Dependency(\.tokenClient) var tokenClient

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // Re-seed the per-presentation mirror from the source of truth (`DevSettings`, persisted by
          // its UserDefaults-backed live value) every time the menu appears.
          state.useMockData = dev.useMockData()
          state.scenarios = Dictionary(
            uniqueKeysWithValues: DevEndpoint.allCases.map { ($0, dev.scenario($0)) }
          )
          state.logEnabled = Dictionary(
            uniqueKeysWithValues: LogCategory.allCases.map { category in
              (category, category.isAlwaysOn ? true : dev.isLogCategoryEnabled(category.rawValue))
            }
          )
          return .none
        case let .useMockDataToggled(enabled):
          state.useMockData = enabled
          dev.setUseMockData(enabled)
          return .none
        case let .scenarioSelected(scenario, endpoint):
          // The writer is a stored `@Sendable` closure (no argument labels), so it is called positionally
          // as `setScenario(scenario, endpoint)` — matching `DevSettings.swift`'s `(SampleScenario,
          // DevEndpoint)` parameter order.
          state.scenarios[endpoint] = scenario
          dev.setScenario(scenario, endpoint)
          return .none
        case let .logCategoryToggled(category, enabled):
          // `.http` is always-on (never gated) — ignore any attempt to flip it.
          guard !category.isAlwaysOn else { return .none }
          state.logEnabled[category] = enabled
          dev.setLogCategoryEnabled(enabled, category.rawValue)
          return .none
        case .viewLogsTapped:
          state.logViewer = LogViewerFeature.State()
          return .none
        case .logViewer:
          return .none
        case .resetTokenTapped:
          // Clear the stored bearer token, then bubble `tokenReset` so the shell swaps to onboarding —
          // re-testing the connect / onboarding flow on demand without uninstalling.
          return .run { [tokenClient] send in
            try? await tokenClient.clear()
            await send(.delegate(.tokenReset))
          }
        case .forceFullResyncTapped:
          // Bubble only — the anchor clear runs in the parent (`SettingsFeature` owns the
          // `SyncRepository` dependency; this menu touches only the app-spine interfaces).
          return .send(.delegate(.fullResyncRequested))
        case .delegate:
          return .none
        }
      }
      .ifLet(\.$logViewer, action: \.logViewer) {
        LogViewerFeature()
      }
    }
  }
#endif
