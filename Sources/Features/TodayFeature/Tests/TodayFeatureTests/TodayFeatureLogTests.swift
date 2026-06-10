import BriefRepository
import CheckInRepository
import Clocks
import CoachCore
import ComposableArchitecture
import LogClient
import SyncRepository
import Testing

@testable import TodayFeature

/// Asserts the `.lifecycle` observability line emitted via `@Dependency(\.log)` when the morning
/// orchestration is triggered (`onAppOpen`). Injects a `LogClient.recording(into:)` recorder and drives
/// the success chain to a terminal; the message is label-only (no payloads / PII).
@MainActor
struct TodayFeatureLogTests {
  @Test func test_onAppOpen_emitsLifecycleLog() async {
    let recorder = LogRecorder()
    let instant = sofiaInstant()
    let brief = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(instant)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in brief }
      $0.log = .recording(into: recorder)
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = instant
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(brief, .fresh) }

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("morning orchestration") })
  }
}
