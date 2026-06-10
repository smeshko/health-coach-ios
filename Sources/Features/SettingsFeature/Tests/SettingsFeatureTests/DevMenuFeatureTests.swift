#if DEBUG
  import ComposableArchitecture
  import DevSettings
  import LogClient
  import SampleData
  import Testing
  import TokenClient

  @testable import SettingsFeature

  /// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for the DEBUG `DevMenuFeature`: `.onAppear`
  /// seeds the mirror from `DevSettings`; `.useMockDataToggled` / `.scenarioSelected` mutate state **and**
  /// call the `DevSettings` writer closures (proven by a writer-recording fake); `.resetTokenTapped`
  /// clears the bearer token (a clear-recording `TokenClient`) and emits `delegate(.tokenReset)`.
  @MainActor
  struct DevMenuFeatureTests {
    /// One recorded `setScenario(_:_:)` write (kept flat — one level of nesting — to satisfy the lint).
    private struct ScenarioWrite: Equatable {
      let scenario: SampleScenario
      let endpoint: DevEndpoint
    }

    /// One recorded `setLogCategoryEnabled(_:_:)` write (kept flat for the nesting lint).
    private struct LogWrite: Equatable {
      let enabled: Bool
      let rawValue: String
    }

    /// A `DevSettings` fake whose getters serve a fixed seed and whose writers record their arguments.
    /// The closures are synchronous (`@Sendable () -> …`), so recording uses a `LockIsolated` box.
    private struct DevSettingsRecorder {
      let setMockCalls = LockIsolated<[Bool]>([])
      let setScenarioCalls = LockIsolated<[ScenarioWrite]>([])
      let setLogCalls = LockIsolated<[LogWrite]>([])

      func make(
        useMockData: Bool,
        seed: [DevEndpoint: SampleScenario],
        enabledLogCategories: Set<String> = []
      ) -> DevSettings {
        DevSettings(
          useMockData: { useMockData },
          scenario: { seed[$0] ?? $0.defaultScenario },
          setUseMockData: { enabled in setMockCalls.withValue { $0.append(enabled) } },
          setScenario: { scenario, endpoint in
            setScenarioCalls.withValue { $0.append(ScenarioWrite(scenario: scenario, endpoint: endpoint)) }
          },
          isLogCategoryEnabled: { enabledLogCategories.contains($0) },
          setLogCategoryEnabled: { enabled, rawValue in
            setLogCalls.withValue { $0.append(LogWrite(enabled: enabled, rawValue: rawValue)) }
          }
        )
      }
    }

    @Test func test_onAppear_seedsStateFromDevSettings() async {
      let seed: [DevEndpoint: SampleScenario] = [
        .dailyBrief: .dailyBriefRed,
        .weeklyPlan: .weeklyPlanDeload,
        .profile: .profile,
        .sync: .syncResponse,
      ]
      let recorder = DevSettingsRecorder()
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = recorder.make(useMockData: true, seed: seed, enabledLogCategories: ["tca"])
      }

      await store.send(.onAppear) {
        $0.useMockData = true
        $0.scenarios = seed
        // Always-on `.http` seeds `true`; the rest reflect `isLogCategoryEnabled` (only `tca` enabled).
        $0.logEnabled = [.http: true, .tca: true, .lifecycle: false, .app: false]
      }
    }

    @Test func test_useMockDataToggled_updatesStateAndWritesThrough() async {
      let recorder = DevSettingsRecorder()
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = recorder.make(useMockData: false, seed: [:])
      }

      await store.send(.useMockDataToggled(true)) { $0.useMockData = true }

      #expect(recorder.setMockCalls.value == [true])
    }

    @Test func test_scenarioSelected_updatesMapAndWritesThrough() async {
      let recorder = DevSettingsRecorder()
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = recorder.make(useMockData: false, seed: [:])
      }

      await store.send(.scenarioSelected(.dailyBriefRestKnee, .dailyBrief)) {
        $0.scenarios[.dailyBrief] = .dailyBriefRestKnee
      }

      #expect(
        recorder.setScenarioCalls.value == [.init(scenario: .dailyBriefRestKnee, endpoint: .dailyBrief)],
        "the writer must be called positionally as setScenario(scenario, endpoint)"
      )
    }

    @Test func test_logCategoryToggled_updatesStateAndWritesThrough() async {
      let recorder = DevSettingsRecorder()
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = recorder.make(useMockData: false, seed: [:])
      }

      await store.send(.logCategoryToggled(.app, true)) { $0.logEnabled[.app] = true }

      #expect(recorder.setLogCalls.value == [.init(enabled: true, rawValue: "app")])
    }

    @Test func test_logCategoryToggled_alwaysOnCategory_isNoOp() async {
      let recorder = DevSettingsRecorder()
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = recorder.make(useMockData: false, seed: [:])
      }

      // `.http` is always-on — toggling it mutates nothing and writes nothing.
      await store.send(.logCategoryToggled(.http, false))

      #expect(recorder.setLogCalls.value.isEmpty)
    }

    @Test func test_resetTokenTapped_clearsTokenAndEmitsDelegate() async {
      let cleared = LockIsolated(false)
      let store = TestStore(initialState: DevMenuFeature.State()) {
        DevMenuFeature()
      } withDependencies: {
        $0.devSettings = .testValue
        $0.tokenClient.clear = { cleared.setValue(true) }
      }

      await store.send(.resetTokenTapped)
      await store.receive(\.delegate, .tokenReset)
      await store.finish()

      #expect(cleared.value, "resetTokenTapped must clear the stored bearer token")
    }
  }
#endif
