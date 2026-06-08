import SampleData

/// DEBUG mock/live routing control (ARCHITECTURE §4.2 / §7.1, D25). A `Sendable` struct of
/// `@Sendable` closures so the live (UserDefaults, `DevSettingsLive`) and test (in-memory)
/// implementations swap cleanly through `@Dependency(\.devSettings)`.
///
/// - `useMockData()` — whether repositories should route to their `.mock(scenario:)` value. Always
///   `false` in RELEASE (`DevSettingsLive` hard-wires it; the routing collapses to `.live`).
/// - `scenario(_:)` — the selected `SampleScenario` for an endpoint (falls back to the endpoint's
///   `defaultScenario`).
/// - `setUseMockData(_:)` / `setScenario(_:for:)` — DEBUG-meaningful writers, so the launch-arg
///   bootstrap (`DevSettingsLive.applyLaunchOverrides`) and the Epic 6.4 dev menu write through one
///   seam. No-ops in RELEASE.
///
/// `SampleScenario` (Phase 2.3) is already `Sendable` at its source, so it crosses these `@Sendable`
/// closure boundaries with no retroactive conformance needed here.
public struct DevSettings: Sendable {
  public var useMockData: @Sendable () -> Bool
  public var scenario: @Sendable (DevEndpoint) -> SampleScenario
  public var setUseMockData: @Sendable (Bool) -> Void
  public var setScenario: @Sendable (SampleScenario, DevEndpoint) -> Void

  public init(
    useMockData: @escaping @Sendable () -> Bool,
    scenario: @escaping @Sendable (DevEndpoint) -> SampleScenario,
    setUseMockData: @escaping @Sendable (Bool) -> Void,
    setScenario: @escaping @Sendable (SampleScenario, DevEndpoint) -> Void
  ) {
    self.useMockData = useMockData
    self.scenario = scenario
    self.setUseMockData = setUseMockData
    self.setScenario = setScenario
  }
}
