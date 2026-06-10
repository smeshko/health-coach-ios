// DEBUG log-viewer snapshot (ARCHITECTURE D16): `LogViewerView` rendering a fixed set of recent log
// lines (newest-first, monospaced, error/notice tinted) in light + dark on the single reference device.
// Guarded on BOTH `#if canImport(UIKit)` (empty module on the macOS host) AND `#if DEBUG` (compiles out
// of RELEASE). Runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  #if DEBUG
    import CoachTestSupport
    import ComposableArchitecture
    import Foundation
    import LogClient
    import SnapshotTesting
    import SwiftUI
    import Testing

    @testable import SettingsFeature

    @MainActor
    struct LogViewerViewSnapshotTests {
      @Test func test_logViewer() {
        let lines = [
          "2026-06-10 12:00:00.000 INFO [lifecycle] app did finish launching",
          "2026-06-10 12:00:00.250 DEBUG [tca] AppFeature.onAppear",
          "2026-06-10 12:00:01.100 NOTICE [http] GET /probe → 200 — ms=84",
          "2026-06-10 12:00:02.500 ERROR [http] GET /brief → 401 — status=401",
        ]
        // Pin `readRecent` to the same lines so the view's `.onAppear` reload is idempotent, and pin
        // `\.date` (the reducer reads it on appear to anchor the date filter; default range is `.all`,
        // so the instant doesn't affect what renders).
        let view = withDependencies {
          $0.log.readRecent = { lines }
          $0.date = .constant(Date(timeIntervalSince1970: 1_749_556_800))
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
