import Dependencies

extension DevSettings: TestDependencyKey {
  /// Mock-on, every endpoint serves its `defaultScenario`, writers are no-ops. This is the value
  /// features see under `withDependencies` / in tests (the epic's "build on fixtures" default).
  public static var testValue: DevSettings {
    DevSettings(
      useMockData: { true },
      scenario: { $0.defaultScenario },
      setUseMockData: { _ in },
      setScenario: { _, _ in }
    )
  }

  /// Same shape as `testValue` — previews run on the default fixtures, mock-on.
  public static var previewValue: DevSettings {
    testValue
  }
}

public extension DependencyValues {
  var devSettings: DevSettings {
    get { self[DevSettings.self] }
    set { self[DevSettings.self] = newValue }
  }
}
