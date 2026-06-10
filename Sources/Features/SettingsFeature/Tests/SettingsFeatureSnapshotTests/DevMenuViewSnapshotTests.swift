// DEBUG dev-menu view snapshot (ARCHITECTURE D16): the `DevMenuView` surface — the MOCK DATA toggle +
// endpoint-filtered scenario pickers, the LOGGING category toggles, and the destructive reset-token
// SESSION action — in light + dark on the single reference device. The body is guarded on BOTH
// `#if canImport(UIKit)` (so it compiles to an empty module on the macOS host — SwiftUI image snapshots
// are UIKit-only) AND `#if DEBUG` (the whole dev menu compiles out of RELEASE). Runs on the iOS 26
// simulator via `make test-snapshots`.

#if canImport(UIKit)
  #if DEBUG
    import CoachTestSupport
    import ComposableArchitecture
    import DevSettings
    import LogClient
    import SampleData
    import SnapshotTesting
    import SwiftUI
    import Testing

    @testable import SettingsFeature

    @MainActor
    struct DevMenuViewSnapshotTests {
      @Test func test_devMenu() {
        // Pre-seed the mirror so the controls render populated regardless of `.onAppear` timing; the
        // fixed `.testValue` DevSettings (mock-on, default scenarios, log categories off) keeps
        // `.onAppear` idempotent.
        var state = DevMenuFeature.State()
        state.useMockData = true
        state.scenarios = Dictionary(
          uniqueKeysWithValues: DevEndpoint.allCases.map { ($0, $0.defaultScenario) }
        )
        state.logEnabled = Dictionary(
          uniqueKeysWithValues: LogCategory.allCases.map { ($0, $0.isAlwaysOn) }
        )
        let view = withDependencies {
          $0.devSettings = .testValue
        } operation: {
          NavigationStack {
            DevMenuView(
              store: Store(initialState: state) { DevMenuFeature() }
            )
          }
        }
        assertCoachSnapshot(of: view)
      }
    }
  #endif
#endif
