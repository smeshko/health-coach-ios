#if DEBUG
  import ComposableArchitecture
  import DevSettings
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

    /// A `DevSettings` fake whose getters serve a fixed seed and whose writers record their arguments.
    /// The closures are synchronous (`@Sendable () -> …`), so recording uses a `LockIsolated` box.
    private struct DevSettingsRecorder {
      let setMockCalls = LockIsolated<[Bool]>([])
      let setScenarioCalls = LockIsolated<[ScenarioWrite]>([])

      func make(useMockData: Bool, seed: [DevEndpoint: SampleScenario]) -> DevSettings {
        DevSettings(
          useMockData: { useMockData },
          scenario: { seed[$0] ?? $0.defaultScenario },
          setUseMockData: { enabled in setMockCalls.withValue { $0.append(enabled) } },
          setScenario: { scenario, endpoint in
            setScenarioCalls.withValue { $0.append(ScenarioWrite(scenario: scenario, endpoint: endpoint)) }
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
        $0.devSettings = recorder.make(useMockData: true, seed: seed)
      }

      await store.send(.onAppear) {
        $0.useMockData = true
        $0.scenarios = seed
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
