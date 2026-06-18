import APIClient
import Clocks
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import HealthKitClient
import LocalRepositories
import PersistenceModels
import SyncRepository
import Testing
import WireModels

@testable import SyncRepositoryLive

/// CR-3 (release audit 2026-06-18): the HK delta read is bounded by `healthReadTimeout` so a wedged
/// HealthKit — `HKSampleQuery`/`HKActivitySummaryQuery` are callback-based and ignore cancellation —
/// can't pin the sync (and the `.syncing` screen) open forever. Split out of `SyncOrchestrationTests` to
/// keep that file under the 400-line cap. Reuses that file's `syncResponse` helper (same test target).
struct SyncTimeoutTests {
  /// 2026-06-08 ~09:00 Europe/Sofia — the same anchor instant the orchestration tests use.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  private func watermark(_ database: DatabaseClient) async throws -> SyncWatermarkRecord? {
    try await database.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
  }

  /// A wedged HealthKit read must NOT pin the sync open forever: `withSyncTimeout` gives up after
  /// `healthReadTimeout` and throws `.transient`. An `ImmediateClock` fires the timeout deterministically
  /// (its sleep returns at once) while the stub `deltaSamples` loses the race, so the timeout branch
  /// always wins — no advance-ordering race. The throw precedes the watermark write, so the seeded
  /// watermark is left untouched (no data loss; the window is re-read next sync) and the POST is never hit.
  @Test func test_sync_healthReadTimesOut_throwsTransient_watermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "222.0", serverTime: Date(timeIntervalSince1970: 222))
    try await db.write { dbx in try seeded.save(dbx) }

    let postReached = LockIsolated(false)
    let hangingHealthKit = HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      // Loses the race to the ImmediateClock timeout (a long sleep, abandoned by `withSyncTimeout` when
      // the timeout fires). A plain `Task.sleep` rather than a parked continuation, so no leak warning.
      deltaSamples: { _ in
        try await Task.sleep(for: .seconds(60))
        return HealthSampleSet()
      }
    )

    await #expect(throws: SyncError.transient) {
      try await withDependencies {
        $0.useEuropeSofia()
        $0.date = .constant(Self.now)
        $0.continuousClock = ImmediateClock()
        $0.healthKitClient = hangingHealthKit
        $0.apiClient = .failing(sync: { _ in
          postReached.withValue { $0 = true }
          return syncResponse()
        })
        $0.database = db
        $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
        $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
      } operation: {
        try await SyncRepository.live.sync()
      }
    }

    #expect(!postReached.value, "the timeout short-circuits before the /sync POST")
    let mark = try await watermark(db)
    #expect(mark == seeded, "a timed-out HK read must leave the watermark untouched")
  }
}
