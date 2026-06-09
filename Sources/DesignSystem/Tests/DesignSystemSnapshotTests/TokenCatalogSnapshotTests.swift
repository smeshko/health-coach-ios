// Token/label catalog snapshot — proves the shared `CoachTestSupport` harness (light + dark, single
// reference device) works for `DesignSystem`. `#if canImport(UIKit)`-guarded so this target compiles
// to an empty module on the macOS host (so `swift test` stays green); it runs on an iOS 26 simulator
// via `xcodebuild test`. The fixture `TokenCatalogView` is internal, reached via `@testable import`.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct TokenCatalogSnapshotTests {
    @Test func test_tokenCatalog() {
      assertCoachSnapshot(of: TokenCatalogView())
    }
  }
#endif
