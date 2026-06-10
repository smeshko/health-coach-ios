#if DEBUG
  import ComposableArchitecture
  import DevSettings
  import SampleData
  import TokenClient

  /// The DEBUG dev menu (ARCHITECTURE §7.1 / D25). It mirrors the `useMockData` flag + the
  /// per-`DevEndpoint` `SampleScenario` map from `@Dependency(\.devSettings)` and writes every change
  /// straight back through the `DevSettings` writers, so the next `*.routed(dev:)` repository call
  /// reflects it with **no relaunch** (the per-call read is Phase 4.1's contract, not this menu's).
  /// `resetTokenTapped` clears the bearer token via `@Dependency(\.tokenClient)` and bubbles a
  /// `tokenReset` delegate so the shell restarts onboarding — re-testing the connect flow on demand.
  ///
  /// The whole surface is `#if DEBUG`, so it compiles out of RELEASE (D25: routing collapses to `.live`).
  /// It touches only the `DevSettings` + `TokenClient` **interfaces** (the app-spine carve-out, §3) — no
  /// repository call, no `*Live`, no DTO/GRDB/HealthKit.
  @Reducer
  public struct DevMenuFeature {
    /// Delegate actions the parent (`SettingsFeature`) listens for.
    public enum Delegate: Equatable {
      /// The bearer token was cleared — the parent routes the app back to onboarding (the connect flow).
      case tokenReset
    }

    @ObservableState
    public struct State: Equatable {
      /// Whether repositories route to their `.mock(scenario:)` value. Mirrors `dev.useMockData()`.
      public var useMockData = false
      /// The selected scenario per endpoint. Mirrors `dev.scenario(_:)` over `DevEndpoint.allCases`.
      public var scenarios: [DevEndpoint: SampleScenario] = [:]
      public init() {}
    }

    public enum Action: Equatable {
      case onAppear
      case useMockDataToggled(Bool)
      case scenarioSelected(SampleScenario, DevEndpoint)
      case resetTokenTapped
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
          // Phase 4.1's `DevSettingsLive`) every time the menu appears.
          state.useMockData = dev.useMockData()
          state.scenarios = Dictionary(
            uniqueKeysWithValues: DevEndpoint.allCases.map { ($0, dev.scenario($0)) }
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
        case .resetTokenTapped:
          // Clear the stored bearer token, then bubble `tokenReset` so the shell swaps to onboarding —
          // re-testing the connect / onboarding flow on demand without uninstalling.
          return .run { [tokenClient] send in
            try? await tokenClient.clear()
            await send(.delegate(.tokenReset))
          }
        case .delegate:
          return .none
        }
      }
    }
  }
#endif
