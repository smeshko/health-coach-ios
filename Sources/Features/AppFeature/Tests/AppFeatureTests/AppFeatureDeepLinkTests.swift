import ComposableArchitecture
import OnboardingFeature
import StrengthTestFeature
import Testing

@testable import AppFeature

/// `TestStore` coverage for the Phase 10.4 deep-link mapping: the weekly strength-test reminder
/// (`reminder.weekly-strength-test`) selects the You tab and pushes one `StrengthTestFeature` element
/// when on `.main`; it is a no-op while onboarding, for an unknown identifier, and on a repeat tap.
@MainActor
struct AppFeatureDeepLinkTests {
  private static let weeklyStrengthTest = "reminder.weekly-strength-test"

  @Test func test_weeklyReminderFromMain_selectsYouTabAndPushesScreen() async {
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.notificationOpened(identifier: Self.weeklyStrengthTest)) {
      $0.mainRoute?.selectedTab = .settings
      $0.mainRoute?.settings.append(.strengthTest(StrengthTestFeature.State()))
    }
  }

  @Test func test_weeklyReminderWhileOnboarding_isDropped() async {
    let store = TestStore(
      initialState: AppFeature.State(route: .onboarding(OnboardingFeature.State()))
    ) {
      AppFeature()
    }
    // No session yet → the session-gated screen has nowhere to land → no state change.
    await store.send(.notificationOpened(identifier: Self.weeklyStrengthTest))
  }

  @Test func test_unknownIdentifier_isNoOp() async {
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.notificationOpened(identifier: "reminder.some-other-thing"))
  }

  @Test func test_doubleTap_doesNotStackTwoScreens() async {
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.notificationOpened(identifier: Self.weeklyStrengthTest)) {
      $0.mainRoute?.selectedTab = .settings
      $0.mainRoute?.settings.append(.strengthTest(StrengthTestFeature.State()))
    }
    // Already on top → the second tap selects the (already-selected) tab and pushes nothing.
    await store.send(.notificationOpened(identifier: Self.weeklyStrengthTest))
  }
}
