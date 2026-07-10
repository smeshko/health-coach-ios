import APIClient
import Clocks
import CoachCore
import Database
import Dependencies
import Foundation
import HealthKitClient
import LocalRepositories
import PersistenceModels
import SyncRepository
import Testing
import WireModels

@testable import SyncRepositoryLive

/// Phase 18.2: the sync's HK read is BOUNDED. `runSync()` must request `HealthReadBounds` carrying
/// since = the watermark anchor plus the documented `.since(_:)` defaults (so the repo can't silently
/// request unbounded reads again), a client-side `HealthKitReadError.timedOut` must surface as the
/// same retryable `SyncError.transient` the outer backstop throws, and cancelling the caller must
/// reach the in-flight `deltaSamples` (the live client stops its queries on that cancellation).
/// Split from `SyncTimeoutTests` (the outer-backstop coverage, behaviour unchanged); reuses that
/// target's `syncResponse` helper.
struct SyncBoundedReadTests {
  /// 2026-06-08 ~09:00 Europe/Sofia — the same anchor instant the orchestration tests use.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  private func watermark(_ database: DatabaseClient) async throws -> SyncWatermarkRecord? {
    try await database.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
  }

  private func healthKit(
    deltaSamples: @escaping @Sendable (HealthReadBounds) async throws -> HealthSampleSet
  ) -> HealthKitClient {
    HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: deltaSamples
    )
  }

  /// The bounds `runSync()` passes to the client: since = the watermark anchor, and the `.since(_:)`
  /// defaults pinned as LITERALS (limit 10 000 / timeout 15s) — a drive-by change to either constant
  /// must consciously update this pin. Also pins the ordering the design relies on: the in-client
  /// timeout fires strictly before the repo's 20s abandoning backstop, so queries are stopped, not
  /// orphaned.
  @Test func test_sync_requestsBoundedRead_sinceAnchor_defaultLimitAndTimeout() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "222.0", serverTime: Date(timeIntervalSince1970: 222))
    try await db.write { dbx in try seeded.save(dbx) }
    let captured = LockIsolated<HealthReadBounds?>(nil)

    _ = try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = healthKit { bounds in
        captured.setValue(bounds)
        return HealthSampleSet()
      }
      $0.apiClient = .failing(sync: { _ in syncResponse() })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      try await SyncRepository.live.sync()
    }

    let bounds = captured.value
    #expect(bounds?.since == Date(timeIntervalSince1970: 222), "since = the watermark anchor")
    #expect(bounds?.limitPerType == 10000, "the documented default per-type row limit")
    #expect(bounds?.timeout == .seconds(15), "the documented default in-client timeout")
    #expect(
      HealthReadBounds.defaultTimeout < healthReadTimeout,
      "the in-client timeout must fire strictly before the 20s abandoning backstop"
    )
  }

  /// A client-side whole-read timeout (`HealthKitReadError.timedOut` — the live client has already
  /// STOPPED its queries) surfaces exactly like the backstop timeout: `SyncError.transient`, thrown
  /// before the POST and before any watermark write.
  @Test func test_sync_clientTimedOut_throwsTransient_watermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "333.0", serverTime: Date(timeIntervalSince1970: 333))
    try await db.write { dbx in try seeded.save(dbx) }
    let postReached = LockIsolated(false)

    await #expect(throws: SyncError.transient) {
      try await withDependencies {
        $0.useEuropeSofia()
        $0.date = .constant(Self.now)
        $0.continuousClock = TestClock()
        $0.healthKitClient = healthKit { _ in throw HealthKitReadError.timedOut }
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

    #expect(!postReached.value, "a client-side timeout short-circuits before the /sync POST")
    let mark = try await watermark(db)
    #expect(mark == seeded, "a client-side timeout must leave the watermark untouched")
  }

  /// Caller cancellation propagates end-to-end (validation round-1 #1): cancelling the task awaiting
  /// `sync()` cancels the in-flight `deltaSamples` — the stub's cancellation handler fires (the live
  /// client stops its `HKQuery`s there), `sync()` rethrows `CancellationError`, NO `/sync` POST
  /// happens (round-2 #1 sync-level arm), and the watermark is untouched. The TestClock never
  /// advances, so neither timeout can be what unblocks the read — only forwarded cancellation can.
  @Test func test_sync_callerCancelled_cancelsDeltaRead_noPost_watermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "444.0", serverTime: Date(timeIntervalSince1970: 444))
    try await db.write { dbx in try seeded.save(dbx) }
    let postReached = LockIsolated(false)
    let readCancelled = LockIsolated(false)
    let readStarted = AsyncStream.makeStream(of: Void.self)

    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = healthKit { _ in
        readStarted.continuation.yield(())
        return try await withTaskCancellationHandler {
          // Parks on a wall-clock sleep `Task.sleep` aborts the instant cancellation arrives
          // (throwing `CancellationError`). Long enough that it can't win legitimately, short
          // enough that a REGRESSION (cancellation not forwarded) fails this test in bounded
          // time instead of hanging the suite.
          try await Task.sleep(for: .seconds(30))
          return HealthSampleSet()
        } onCancel: {
          readCancelled.withValue { $0 = true }
        }
      }
      $0.apiClient = .failing(sync: { _ in
        postReached.withValue { $0 = true }
        return syncResponse()
      })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      let sync = Task { try await SyncRepository.live.sync() }
      var started = readStarted.stream.makeAsyncIterator()
      _ = await started.next() // the delta read is in flight — cancel mid-read
      sync.cancel()
      await #expect(throws: CancellationError.self) { try await sync.value }
    }

    #expect(readCancelled.value, "caller cancellation must reach the in-flight deltaSamples")
    #expect(!postReached.value, "a cancelled read must never proceed to the /sync POST")
    let mark = try await watermark(db)
    #expect(mark == seeded, "a cancelled sync must leave the watermark untouched")
  }
}
