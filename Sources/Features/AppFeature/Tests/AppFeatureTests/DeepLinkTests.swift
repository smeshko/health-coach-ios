import CoachCore
import ComposableArchitecture
import Foundation
import OnboardingFeature
import Testing

@testable import AppFeature

/// `TestStore` coverage for the Phase 21.1 `coachapp://` URL routing: the three deep links pick
/// their tab from `.main`, are dropped while onboarding, and unknown URLs are a no-op.
@MainActor
struct DeepLinkTests {
  @Test func test_weeklyURL_fromMainOnToday_selectsWeeklyTab() async {
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.deepLink(CoachDeepLink.weekly.url)) {
      $0.mainRoute?.selectedTab = .weekly
    }
  }

  @Test func test_todayURL_fromMainOnWeekly_selectsTodayTab() async {
    var main = MainTabs.State()
    main.selectedTab = .weekly
    let store = TestStore(initialState: AppFeature.State(route: .main(main))) {
      AppFeature()
    }
    await store.send(.deepLink(CoachDeepLink.today.url)) {
      $0.mainRoute?.selectedTab = .today
    }
  }

  @Test func test_checkInURL_landsOnTodayTab() async {
    var main = MainTabs.State()
    main.selectedTab = .settings
    let store = TestStore(initialState: AppFeature.State(route: .main(main))) {
      AppFeature()
    }
    // The check-in flow IS the Today tab's checkInRequired gate — the route only picks the tab.
    await store.send(.deepLink(CoachDeepLink.checkIn.url)) {
      $0.mainRoute?.selectedTab = .today
    }
  }

  @Test func test_deepLinkWhileOnboarding_isDropped() async {
    let store = TestStore(
      initialState: AppFeature.State(route: .onboarding(OnboardingFeature.State()))
    ) {
      AppFeature()
    }
    await store.send(.deepLink(CoachDeepLink.weekly.url))
  }

  @Test func test_unknownHostURL_isNoOp() async throws {
    let url = try #require(URL(string: "coachapp://nope"))
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.deepLink(url))
  }

  @Test func test_foreignSchemeURL_isNoOp() async throws {
    let url = try #require(URL(string: "https://example.com"))
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    }
    await store.send(.deepLink(url))
  }
}
