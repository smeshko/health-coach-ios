import APIClient
import BriefRepository
import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import LocalRepositories
import OnboardingFeature
import ProfileRepository
import SampleData
import SyncRepository
import Testing

@testable import AppFeature

/// Audit gap / 11.1 DECISIONS D6: the 401-mid-orchestration CONTAINMENT pin. The deleted no-op
/// `appWork` cancel is replaced by TCA's real containment — when AppFeature swaps `.main → .onboarding`
/// on a 401, the `.ifCaseLet(\.main)` teardown cancels the in-flight TodayFeature sync→brief chain, so a
/// late `_briefResolved` never lands in the (now torn-down) `.main` state. This drives a SUSPENDED Today
/// orchestration (the brief parked on a continuation) through the AppFeature reducer, delivers the 401,
/// then releases the brief and asserts (via the exhaustive store) that no `_briefResolved` arrives.
@MainActor
struct AppFeature401OrchestrationTests {
  @Test func test_unauthorizedMidOrchestration_swapsToOnboarding_tearsDownTodayChain() async {
    let now = sofiaInstant()
    let (sessionStream, sessionContinuation) = AsyncStream.makeStream(of: SessionEvent.self)
    // Park the brief request: `dailyBrief` awaits this stream so the orchestration suspends between
    // `_generating` and `_briefResolved` until the test releases it.
    let (briefGate, briefGateContinuation) = AsyncStream.makeStream(of: Void.self)

    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.apiClient.sessionEvents = { sessionStream }
      $0.checkInRepository.current = { _ in
        DomainModels.CheckIn(
          date: Calendar.europeSofia.startOfDay(for: now), giSymptoms: false, kneePain: 0, illness: false
        )
      }
      $0.syncRepository.sync = {
        SyncResult(
          recordsUpserted: 0, recordsDuplicate: 0, workoutsUpserted: 0, activityDaysUpserted: 0,
          checkinSaved: false, strengthTestSaved: false, serverTime: Date(timeIntervalSince1970: 0)
        )
      }
      // `zones()` is non-optional; the orchestration wraps it in `try?`, so a throw degrades to nil.
      $0.profileRepository.zones = { throw CancellationError() }
      $0.briefRepository.dailyBrief = { _ in
        // Suspend here until the test resumes the gate (the 401 must land while the brief is in-flight).
        var iterator = briefGate.makeAsyncIterator()
        _ = await iterator.next()
        return SampleData.dailyBriefGreen
      }
    }

    // Subscribe to the 401 stream, then start the morning orchestration. It runs the check-in gate +
    // sync, reaches `.generating`, and parks on the brief request.
    await store.send(._appWillAppear)
    await store.send(.main(.todayRoot(.onAppOpen)))
    await store.receive(\.main.todayRoot._syncStarted) {
      $0.route = .main(Self.main { $0.todayRoot.briefState = .syncing })
    }
    await store.receive(\.main.todayRoot._generating) {
      $0.route = .main(Self.main {
        $0.todayRoot.lastSyncedAt = now
        $0.todayRoot.briefState = .generating
      })
    }

    // Deliver a 401 WHILE the brief is parked → AppFeature swaps `.main → .onboarding`; the `.ifCaseLet`
    // teardown cancels the in-flight Today orchestration.
    sessionContinuation.yield(.unauthorized)
    await store.receive(\._sessionEvent, .unauthorized) {
      $0.route = .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
    }

    // Release the parked brief. The orchestration effect was torn down, so its `await send(._briefResolved)`
    // runs on a cancelled task and delivers NOTHING — the exhaustive store (and `finish`) prove no late
    // `_briefResolved` lands in the now-`.onboarding` state.
    briefGateContinuation.yield(())
    briefGateContinuation.finish()
    sessionContinuation.finish()
    await store.finish()

    #expect(store.state.onboardingRoute != nil, "the 401 swapped to onboarding, containing the Today chain")
  }

  /// A `MainTabs.State` built with a mutating closure (keeps the `receive` mutation expressions terse).
  private static func main(_ mutate: (inout MainTabs.State) -> Void) -> MainTabs.State {
    var state = MainTabs.State()
    mutate(&state)
    return state
  }
}

/// A wall-clock instant in Europe/Sofia (mirrors TodayFeature's test frame; that target's helper isn't
/// importable here).
private func sofiaInstant() -> Date {
  Calendar.europeSofia.date(
    from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)
  )!
}
