import APIClient
import Clocks
import CoachCore
import Database
import Dependencies
import Foundation
import HealthKitClient
import LocalRepositories
import LogClient
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
/// 2026-06-08 ~09:00 Europe/Sofia — the same anchor instant the orchestration tests use. Shared by
/// both suites in this file.
private let boundsTestNow = Date(timeIntervalSince1970: 1_780_898_400)

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

struct SyncBoundedReadTests {
  private static let now = boundsTestNow

  private func watermark(_ database: DatabaseClient) async throws -> SyncWatermarkRecord? {
    try await database.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
  }

  /// The bounds `runSync()` passes to the client: since = the watermark anchor MINUS the 48h
  /// late-arrival lookback (Phase 19.1 — samples landing on the phone after the sync that covers
  /// their startDate must be re-read, not permanently dropped), and the `.since(_:)` defaults pinned
  /// as LITERALS (limit 10 000 / timeout 15s) — a drive-by change to either constant must consciously
  /// update this pin. Also pins the ordering the design relies on: the in-client timeout fires
  /// strictly before the repo's 20s abandoning backstop, so queries are stopped, not orphaned.
  @Test func test_sync_requestsBoundedRead_sinceAnchorMinusLookback_defaultLimitAndTimeout() async throws {
    let db = try DatabaseClient.makeInMemory()
    // A realistic anchor well after `backfillFloor + 48h`, so no clamping is in play here.
    let anchor = Self.now
    let seeded = SyncWatermarkRecord(anchor: anchorString(anchor), serverTime: Date(timeIntervalSince1970: 222))
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
    #expect(
      bounds?.since == anchor.addingTimeInterval(-48 * 60 * 60),
      "since = the watermark anchor − the 48h late-arrival lookback"
    )
    #expect(bounds?.limitPerType == 10000, "the documented default per-type row limit")
    #expect(bounds?.timeout == .seconds(15), "the documented default in-client timeout")
    #expect(
      HealthReadBounds.defaultTimeout < healthReadTimeout,
      "the in-client timeout must fire strictly before the 20s abandoning backstop"
    )
  }

  /// The lookback is clamped at `backfillFloor`: an anchor within 48h of the floor must not let the
  /// read reach past the intentional backfill cutoff (Phase 19.1 — the floor marks history that was
  /// exported separately and is deliberately skipped).
  @Test func test_sync_anchorNearBackfillFloor_sinceClampsAtFloor() async throws {
    let db = try DatabaseClient.makeInMemory()
    // One hour after the floor — the naive `anchor − 48h` would land 47h BEFORE the floor.
    let anchor = backfillFloor.addingTimeInterval(60 * 60)
    let seeded = SyncWatermarkRecord(anchor: anchorString(anchor), serverTime: Date(timeIntervalSince1970: 222))
    try await db.write { dbx in try seeded.save(dbx) }
    let captured = LockIsolated<HealthReadBounds?>(nil)

    _ = try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = healthKit { bounds in
        // FIRST window only — a near-floor anchor makes this a chunked backfill, and the clamp
        // under test applies to where the whole read STARTS.
        if captured.value == nil { captured.setValue(bounds) }
        return HealthSampleSet()
      }
      $0.apiClient = .failing(sync: { _ in syncResponse() })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      try await SyncRepository.live.sync()
    }

    #expect(
      captured.value?.since == backfillFloor,
      "an anchor within 48h of the backfill floor floors the read at backfillFloor, never before it"
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

  /// Review #1.1: cancellation racing a SUCCESSFULLY completing delta read must still block the
  /// side effects. The read resumes success before cancellation is observed (here: cancellation
  /// lands while `runSync` is inside the check-in read, whose `try?` swallows `CancellationError`),
  /// leaving `runSync` mid-flight in a cancelled task with samples in hand — the cooperative check
  /// before the POST must throw, so no `/sync` POST and no watermark write happen.
  @Test func test_sync_cancelledAfterSuccessfulRead_noPost_watermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "555.0", serverTime: Date(timeIntervalSince1970: 555))
    try await db.write { dbx in try seeded.save(dbx) }
    let postReached = LockIsolated(false)
    let checkInStarted = AsyncStream.makeStream(of: Void.self)
    let parked = AsyncStream.makeStream(of: Void.self)

    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = healthKit { _ in HealthSampleSet() } // the read completes as success
      $0.apiClient = .failing(sync: { _ in
        postReached.withValue { $0 = true }
        return syncResponse()
      })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in
        checkInStarted.continuation.yield(())
        // Parks until the caller's cancellation lands (nothing ever yields to `parked`;
        // `AsyncStream.next()` returns nil the moment the task is cancelled), then returns
        // NORMALLY — simulating a local read that swallows cancellation, exactly the state the
        // once-guard race leaves behind.
        var unblock = parked.stream.makeAsyncIterator()
        _ = await unblock.next()
        return nil
      })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      let sync = Task { try await SyncRepository.live.sync() }
      var started = checkInStarted.stream.makeAsyncIterator()
      _ = await started.next() // the read has already succeeded — cancel before the POST boundary
      sync.cancel()
      await #expect(throws: CancellationError.self) { try await sync.value }
    }

    #expect(!postReached.value, "a sync cancelled after a successful read must never POST")
    let mark = try await watermark(db)
    #expect(mark == seeded, "a sync cancelled after a successful read must not advance the watermark")
  }

  /// Review #1.1, last boundary: cancellation landing DURING the `/sync` POST (the transport
  /// resumes with a response anyway) must not advance the watermark — the cooperative check before
  /// the write throws, and the already-accepted window is simply re-sent next sync (idempotent).
  @Test func test_sync_cancelledDuringPost_watermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: "666.0", serverTime: Date(timeIntervalSince1970: 666))
    try await db.write { dbx in try seeded.save(dbx) }
    let postStarted = AsyncStream.makeStream(of: Void.self)
    let parked = AsyncStream.makeStream(of: Void.self)

    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = healthKit { _ in HealthSampleSet() }
      $0.apiClient = .failing(sync: { _ in
        postStarted.continuation.yield(())
        // Parks until cancellation lands, then resumes with a SUCCESS response regardless —
        // simulating a transport that completed as the user cancelled.
        var unblock = parked.stream.makeAsyncIterator()
        _ = await unblock.next()
        return syncResponse()
      })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      let sync = Task { try await SyncRepository.live.sync() }
      var started = postStarted.stream.makeAsyncIterator()
      _ = await started.next() // the POST is in flight — cancel before it resumes
      sync.cancel()
      await #expect(throws: CancellationError.self) { try await sync.value }
    }

    let mark = try await watermark(db)
    #expect(mark == seeded, "a sync cancelled during the POST must not advance the watermark")
  }
}

/// Truncation visibility (Phase 19.1, validation round-1 #1): the bounded delta read truncates
/// newest-first, cutting the OLDEST rows in the window — exactly where a late-arriving old-startDate
/// sample sorts — so a per-type count hitting `limitPerType` silently defeats the lookback and must
/// be visible on device.
struct SyncDeltaTruncationTests {
  private static let now = boundsTestNow

  private func records(_ count: Int, type: RecordType = .heartRate) -> [HealthRecordPayload] {
    (0..<count).map { index in
      HealthRecordPayload(
        uuid: "\(type.rawValue)-\(index)",
        type: type,
        start: Self.now.addingTimeInterval(Double(index)),
        end: Self.now.addingTimeInterval(Double(index) + 1)
      )
    }
  }

  /// The pure counting seam: a per-type count AT `limitPerType` flags that type as (likely)
  /// truncated; counts below the limit flag nothing. Workouts and activity summaries are their own
  /// buckets.
  @Test func test_truncatedTypes_flagsTypeAtLimit_notBelow() {
    let atLimit = HealthSampleSet(records: records(3) + records(2, type: .stepCount))
    #expect(
      truncatedTypes(in: atLimit, limitPerType: 3) == ["heart_rate"],
      "a record type AT the limit is flagged; one below is not"
    )

    let below = HealthSampleSet(records: records(2))
    #expect(
      truncatedTypes(in: below, limitPerType: 3).isEmpty,
      "counts below the limit flag nothing"
    )

    let workout = WorkoutPayload(uuid: "w", type: "running", start: Self.now, end: Self.now, durationS: 1)
    let summary = ActivitySummaryPayload(date: Self.now, activeEnergyKcal: 1, exerciseMinutes: 1, standHours: 1)
    let aggregates = HealthSampleSet(workouts: [workout], activity: [summary])
    #expect(
      truncatedTypes(in: aggregates, limitPerType: 1) == ["activity_summaries", "workouts"],
      "workouts and activity summaries are counted as their own buckets"
    )
  }

  /// End-to-end visibility: a delta read returning a per-type count at `limitPerType` logs a
  /// truncation warning on the always-on `.http` category (the Epic-18 convention for audit-critical
  /// records — `.app` is toggle-gated), so the condition is diagnosable on device.
  @Test func test_sync_deltaReadAtLimit_logsTruncationWarning_onHttp() async throws {
    let db = try DatabaseClient.makeInMemory()
    let seeded = SyncWatermarkRecord(anchor: anchorString(Self.now), serverTime: Date(timeIntervalSince1970: 222))
    try await db.write { dbx in try seeded.save(dbx) }
    let recorder = LogRecorder()
    let full = HealthSampleSet(records: records(HealthReadBounds.defaultLimitPerType))

    _ = try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.log = .recording(into: recorder)
      $0.healthKitClient = healthKit { _ in full }
      $0.apiClient = .failing(sync: { _ in syncResponse() })
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      try await SyncRepository.live.sync()
    }

    let warnings = recorder.entries.filter { $0.message.contains("truncated") }
    #expect(warnings.count == 1, "a full per-type bucket logs exactly one truncation warning")
    #expect(warnings.first?.category == .http, "truncation must land on the always-on .http category")
    #expect(
      warnings.first?.message.contains("heart_rate") == true,
      "the warning names the truncated type(s)"
    )
  }
}
