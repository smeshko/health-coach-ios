#if DEBUG
  import ComposableArchitecture
  import LogClient
  import Testing

  @testable import SettingsFeature

  /// `TestStore` coverage for the DEBUG log viewer: `.onAppear` and `.refreshTapped` load recent lines
  /// from `@Dependency(\.log).readRecent()` (a stub) and flip `isLoading` around the load.
  @MainActor
  struct LogViewerFeatureTests {
    @Test func test_onAppear_loadsRecentLines() async {
      let store = TestStore(initialState: LogViewerFeature.State()) {
        LogViewerFeature()
      } withDependencies: {
        $0.log.readRecent = { ["12:00:00.000 INFO [app] started", "12:00:01.000 ERROR [http] boom"] }
      }

      await store.send(.onAppear) { $0.isLoading = true }
      await store.receive(\.logsLoaded) {
        $0.isLoading = false
        $0.lines = ["12:00:00.000 INFO [app] started", "12:00:01.000 ERROR [http] boom"]
      }
    }

    @Test func test_refreshTapped_reloadsLines() async {
      let store = TestStore(initialState: LogViewerFeature.State(lines: ["old"])) {
        LogViewerFeature()
      } withDependencies: {
        $0.log.readRecent = { ["fresh"] }
      }

      await store.send(.refreshTapped) { $0.isLoading = true }
      await store.receive(\.logsLoaded) {
        $0.isLoading = false
        $0.lines = ["fresh"]
      }
    }
  }
#endif
