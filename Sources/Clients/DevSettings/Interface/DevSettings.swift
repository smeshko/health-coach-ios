import SampleData

/// DEBUG mock/live routing control (ARCHITECTURE §4.2 / §7.1, D25). A `Sendable` struct of
/// `@Sendable` closures so the live (UserDefaults, `DevSettingsLive`) and test (in-memory)
/// implementations swap cleanly through `@Dependency(\.devSettings)`.
///
/// - `useMockData()` — whether repositories should route to their `.mock(scenario:)` value. Always
///   `false` in RELEASE (`DevSettingsLive` hard-wires it; the routing collapses to `.live`).
/// - `scenario(_:)` — the selected `SampleScenario` for an endpoint (falls back to the endpoint's
///   `defaultScenario`).
/// - `setUseMockData(_:)` / `setScenario(_:for:)` — DEBUG-meaningful writers, so the first-launch
///   seed (`DevSettingsLive.seedFirstLaunchDefault`) and the Epic 6.4 dev menu write through one
///   seam. No-ops in RELEASE.
/// - `isLogCategoryEnabled(_:)` / `setLogCategoryEnabled(_:_:)` — the **persisted** per-log-category
///   enabled flag `LogClientLive` gates verbose categories on (`.http` is always-on and never
///   consults this). Keyed by the category **rawValue string** so `DevSettings` need not import
///   `LogClient` (no client→client interface edge; DECISIONS 3). DEBUG-meaningful; the Phase 7.4 dev
///   menu surfaces these as switches over this same seam. Default-off (the initializer defaults +
///   the RELEASE branch resolve every category to off); only the DEBUG `live(store:)` persists them.
///
/// `SampleScenario` (Phase 2.3) is already `Sendable` at its source, so it crosses these `@Sendable`
/// closure boundaries with no retroactive conformance needed here.
public struct DevSettings: Sendable {
  public var useMockData: @Sendable () -> Bool
  public var scenario: @Sendable (DevEndpoint) -> SampleScenario
  public var setUseMockData: @Sendable (Bool) -> Void
  public var setScenario: @Sendable (SampleScenario, DevEndpoint) -> Void
  public var isLogCategoryEnabled: @Sendable (_ rawValue: String) -> Bool
  public var setLogCategoryEnabled: @Sendable (_ enabled: Bool, _ rawValue: String) -> Void

  /// The two `logCategory` closures default to **off / no-op** so existing construction sites (the
  /// `testValue`/`previewValue`/RELEASE values + the cross-module test fakes) keep compiling and the
  /// default-off posture is encoded once; only the DEBUG `live(store:)` opts into persistence.
  public init(
    useMockData: @escaping @Sendable () -> Bool,
    scenario: @escaping @Sendable (DevEndpoint) -> SampleScenario,
    setUseMockData: @escaping @Sendable (Bool) -> Void,
    setScenario: @escaping @Sendable (SampleScenario, DevEndpoint) -> Void,
    isLogCategoryEnabled: @escaping @Sendable (_ rawValue: String) -> Bool = { _ in false },
    setLogCategoryEnabled: @escaping @Sendable (_ enabled: Bool, _ rawValue: String) -> Void = { _, _ in }
  ) {
    self.useMockData = useMockData
    self.scenario = scenario
    self.setUseMockData = setUseMockData
    self.setScenario = setScenario
    self.isLogCategoryEnabled = isLogCategoryEnabled
    self.setLogCategoryEnabled = setLogCategoryEnabled
  }
}
