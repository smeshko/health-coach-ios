import ComposableArchitecture
import XCTest

@testable import AppFeature

/// Sample **exhaustive** `TestStore` test (ARCHITECTURE D18) — proves the reducer-test harness is
/// wired. `TestStore` is exhaustive by default: sending an action with no trailing closure asserts
/// that no state mutation and no effect occurred.
@MainActor
final class AppFeatureTests: XCTestCase {
  func testOnAppearIsANoOp() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    // `.onAppear` is a placeholder no-op; the exhaustive store fails if it mutates state or emits an
    // effect we don't assert.
    await store.send(.onAppear)
  }
}
