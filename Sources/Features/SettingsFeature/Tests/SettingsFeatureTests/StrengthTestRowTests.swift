import ComposableArchitecture
import Testing

@testable import SettingsFeature

/// `TestStore` coverage for the Phase 10.4 Strength-test entry row: tapping it bubbles
/// `Delegate.openStrengthTest` up to the shell (which pushes the `StrengthTestFeature` screen). The
/// due-dot is a parent-set field rendered by the view; there is no repository read here.
@MainActor
struct StrengthTestRowTests {
  @Test func test_strengthTestRowTapped_emitsOpenStrengthTestDelegate() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    }
    await store.send(.strengthTestRowTapped)
    await store.receive(\.delegate, .openStrengthTest)
  }
}
