// DEBUG log-viewer snapshot (ARCHITECTURE D16): `LogViewerView` rendering a fixed set of recent log
// lines (newest-first, monospaced, error/notice tinted) in light + dark on the single reference device.
// Guarded on BOTH `#if canImport(UIKit)` (empty module on the macOS host) AND `#if DEBUG` (compiles out
// of RELEASE). Runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  #if DEBUG
    import CoachTestSupport
    import ComposableArchitecture
    import LogClient
    import SnapshotTesting
    import SwiftUI
    import Testing

    @testable import SettingsFeature

    @MainActor
    struct LogViewerViewSnapshotTests {
      @Test func test_logViewer() {
        let lines = [
          "12:00:00.000 INFO [lifecycle] app did finish launching",
          "12:00:00.250 DEBUG [tca] AppFeature.onAppear",
          "12:00:01.100 NOTICE [http] GET /probe → 200 — ms=84",
          "12:00:02.500 ERROR [http] GET /brief → 401 — status=401",
        ]
        // Pin `readRecent` to the same lines so the view's `.onAppear` reload is idempotent.
        let view = withDependencies {
          $0.log.readRecent = { lines }
        } operation: {
          NavigationStack {
            LogViewerView(
              store: Store(initialState: LogViewerFeature.State(lines: lines)) { LogViewerFeature() }
            )
          }
        }
        assertCoachSnapshot(of: view)
      }
    }
  #endif
#endif
