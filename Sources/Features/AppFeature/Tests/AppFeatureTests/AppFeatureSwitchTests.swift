import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import LogClient
import OnboardingFeature
import SampleData
import SettingsFeature
import Testing

@testable import AppFeature

/// Exhaustive `TestStore` tests (ARCHITECTURE D18) for the Phase 7.1 shell: the enum-state
/// `.onboarding ↔ .main` switch and the per-tab `StackState` independence. The 401 routing effect is
/// covered separately in `AppFeature401Tests` (TASK-002).
@MainActor
struct AppFeatureSwitchTests {
  /// The app defaults to `.main` (the session-restore design: start in `.main`, the background token
  /// check swaps to onboarding only when no token is stored — a returning user lands straight on the
  /// app). If this default flips, a stored-token launch would wrongly stick on Connect (review #2.2).
  @Test func test_defaultState_isMain() {
    // Phase 12.4: the launch default is route `.main` AND `isRestoringSession == true` (the restore overlay
    // is up until the token check resolves).
    #expect(AppFeature.State().route == .main(MainTabs.State()))
    #expect(AppFeature.State().isRestoringSession)
  }

  /// A nil OR empty stored token both fall back to onboarding (parameterized — the two cases share the
  /// `._tokenChecked(false)` receive path). Folds the former AppFeatureLogTests.test_restoreSession_*
  /// log asserts (audit MERGE): the `.lifecycle` "Restoring session" + `.app` onboarding-fallback lines
  /// are asserted here on the same `._restoreSession` walk.
  @Test(arguments: [String?.none, ""])
  func test_restoreSession_missingToken_swapsToOnboarding(token: String?) async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { token }
      $0.log = .recording(into: recorder)
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      // Token-less arm: route swaps to onboarding AND the restore overlay lifts (Phase 12.4, D1).
      $0.route = .onboarding(OnboardingFeature.State())
      $0.isRestoringSession = false
    }

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("Restoring session") })
    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("falling back to onboarding") })
  }

  @Test func test_restoreSession_storedToken_staysInMain_andDispatchesOnAppOpen() async {
    // The happy path: a token exists → the default `.main` is kept, AND the reducer dispatches the Today
    // cache-first open (Phase 12.1, DECISIONS D8). `current` returns nil so the open lands at the check-in
    // gate (no sync/network), keeping this an enum-routing test.
    let now = sofiaInstant()
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.tokenClient.read = { "stored-bearer-token" }
      $0.checkInRepository.current = { _ in nil }
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, true) {
      // Token-bearing arm: the route stays `.main` but the restore overlay lifts (Phase 12.4, D1).
      $0.isRestoringSession = false
    }
    // D8: the token-bearing staying-put branch dispatches the Today open.
    await store.receive(\.main.todayRoot.onAppOpen)
    await store.receive(\.main.todayRoot._checkInRequired) {
      $0.route = .main(Self.main { $0.todayRoot.briefState = .checkInRequired })
    }
  }

  /// D8 (round-3 #1): a token-LESS launch with a same-day cached brief swaps to onboarding and NEVER
  /// dispatches `.onAppOpen`, so the cached Today content is never hydrated before the swap. The
  /// `cachedDailyBrief` stub would return a brief if the open ran — its absence from the walk (exhaustive
  /// store) proves the open was never triggered.
  @Test func test_restoreSession_missingToken_neverDispatchesOnAppOpen() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
      $0.briefRepository.cachedDailyBrief = { SampleData.dailyBriefGreen }
      $0.checkInRepository.current = { _ in
        DomainModels.CheckIn(date: Date(), giSymptoms: false, kneePain: 0, illness: false)
      }
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      $0.route = .onboarding(OnboardingFeature.State())
      $0.isRestoringSession = false
    }
    // No `.main.todayRoot.onAppOpen` (or any Today action) in the exhaustive walk → the open never ran.
    await store.finish()
  }

  @Test func test_connectedDelegate_swapsToMain_andDispatchesOnAppOpen() async {
    // Folds the former AppFeatureLogTests.test_connected_emitsAppLog (audit MERGE): the `.app`
    // "Connected" line is asserted here on the same connected-swap walk. D8: post-connect also dispatches
    // the Today cache-first open (the connected branch is token-bearing).
    let now = sofiaInstant()
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State(route: .onboarding(OnboardingFeature.State()))) {
      AppFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.log = .recording(into: recorder)
      $0.checkInRepository.current = { _ in nil }
    }

    await store.send(.onboarding(.delegate(.connected))) {
      $0.route = .main(MainTabs.State())
    }
    await store.receive(\.main.todayRoot.onAppOpen)
    await store.receive(\.main.todayRoot._checkInRequired) {
      $0.route = .main(Self.main { $0.todayRoot.briefState = .checkInRequired })
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Connected") })
  }

  @Test func test_settingsTokenReset_bubblesThroughMainTabs_toOnboarding() async {
    // Full route: the You-tab root's `tokenReset` delegate bubbles through `MainTabs` (which re-emits
    // its own `.delegate(.tokenReset)`) up to `AppFeature`, which swaps to onboarding. (The former
    // test_mainTokenResetDelegate_swapsToOnboarding folded here — audit MERGE — this full bubble is the
    // strictly-stronger walk.) Also folds AppFeatureLogTests.test_tokenReset_emitsAppLog: the `.app`
    // "Token reset" line is asserted on this same delegate walk.
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    await store.send(.main(.settingsRoot(.delegate(.tokenReset))))
    await store.receive(\.main.delegate, .tokenReset) {
      $0.route = .onboarding(OnboardingFeature.State())
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Token reset") })
  }

  @Test func test_perTabStacks_startEmpty() async {
    // The Week / You drill-down stacks are caseless until Epics 9/10 add pushable destinations; the
    // named slots exist and start empty. Stack-independence under pushes returns with those cases.
    let mainState = MainTabs.State()
    #expect(mainState.weekly.count == 0)
    #expect(mainState.settings.count == 0)
  }

  /// A `MainTabs.State` built with a mutating closure (keeps the `receive` mutation expressions terse).
  private static func main(_ mutate: (inout MainTabs.State) -> Void) -> MainTabs.State {
    var state = MainTabs.State()
    mutate(&state)
    return state
  }
}

/// A wall-clock instant in Europe/Sofia (the pinned frame) for the D8 open-dispatch walks.
private func sofiaInstant() -> Date {
  Calendar.europeSofia.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))!
}
