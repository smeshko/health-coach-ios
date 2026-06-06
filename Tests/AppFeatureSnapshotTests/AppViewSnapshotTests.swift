// Sample view snapshot test — proves the `CoachTestSupport` harness is wired (light + dark, single
// reference device). The whole body is `#if canImport(UIKit)`-guarded so this target compiles to an
// empty module on the macOS host (so `swift test` stays green); it runs on an iOS 26 simulator via
// `xcodebuild test`.

#if canImport(UIKit)
  import AppFeature
  import CoachTestSupport
  import ComposableArchitecture
  import SnapshotTesting
  import XCTest

  @MainActor
  final class AppViewSnapshotTests: XCTestCase {
    func testAppViewPlaceholder() {
      let view = AppView(
        store: Store(initialState: AppFeature.State()) { AppFeature() }
      )
      assertCoachSnapshot(of: view)
    }
  }
#endif
