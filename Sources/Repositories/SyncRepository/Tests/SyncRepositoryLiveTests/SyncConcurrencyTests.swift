import APIClient
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import HealthKitClient
import LocalRepositories
import PersistenceModels
import SyncRepository
import Testing
import WireModels

@testable import SyncRepositoryLive

/// Concurrent-call characterization for the sync orchestrator (audit gap #8; DECISIONS.md D2). Split out
/// of `SyncOrchestrationTests` to keep that file under the 400-line cap. Reuses that file's `SyncStubs`
/// helpers (`syncResponse`) — same test target — and the `anchorString` helper from the live module.
struct SyncConcurrencyTests {
  /// 2026-06-08 ~09:00 Europe/Sofia — same anchor instant the orchestration tests use.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  private func watermark(_ database: DatabaseClient) async throws -> SyncWatermarkRecord? {
    try await database.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
  }

  /// Pins — does NOT serialize — what two concurrent `runSync()` calls do to the watermark (DECISIONS.md
  /// D2). Each call's POST is gated on its own continuation so both have already read the SAME seed
  /// watermark before either writes; releasing them one at a time makes the write order deterministic.
  /// Outcome: the last writer wins — the second sync, holding the stale seed read, overwrites the first's
  /// watermark (here observable on `serverTime`; both write the same anchor since `readInstant` is the
  /// constant test clock). No in-flight guard ships: the only caller serializes via `cancelInFlight`, so
  /// this race is unreachable in-app. A refactor adding a guard would flip this test, the tripwire to
  /// revisit serialization (e.g. if a second caller appears).
  @Test func test_concurrentSync_lastWriterWins_noGuard() async throws {
    let db = try DatabaseClient.makeInMemory()
    // Seed a known starting watermark so we can prove both concurrent reads see it (no serialization).
    let seed = SyncWatermarkRecord(anchor: "100.0", serverTime: Date(timeIntervalSince1970: 100))
    try await db.write { dbx in try seed.save(dbx) }

    // Per-call POST gates so both syncs are in flight together, plus an `entered` signal so the test can
    // force a deterministic entry (and therefore write) order. Distinct `serverTime`s per call reveal
    // which write landed last.
    let callCount = LockIsolated(0)
    let releaseConts = LockIsolated<[Int: AsyncStream<Void>.Continuation]>([:])
    let entered = AsyncStream.makeStream(of: Int.self)
    let serverTimes = [Date(timeIntervalSince1970: 1000), Date(timeIntervalSince1970: 2000)]

    let healthKit = HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: { _ in HealthSampleSet() }
    )
    let gatedAPI = APIClient.failing(sync: { _ in
      let index = callCount.withValue { count -> Int in
        defer { count += 1 }
        return count
      }
      let (releaseStream, releaseCont) = AsyncStream.makeStream(of: Void.self)
      releaseConts.withValue { $0[index] = releaseCont }
      entered.continuation.yield(index) // signal: this call read the seed and is parked at the POST
      for await _ in releaseStream { break }
      return syncResponse(serverTime: serverTimes[index])
    })

    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.healthKitClient = healthKit
      $0.apiClient = gatedAPI
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      var entryIter = entered.stream.makeAsyncIterator()

      // Start the first sync and wait until it has read the seed and parked at the POST (→ index 0).
      let first = Task { try await SyncRepository.live.sync() }
      #expect(await entryIter.next() == 0)

      // Start the second; it reads the SAME seed watermark (the first hasn't written yet) (→ index 1).
      let second = Task { try await SyncRepository.live.sync() }
      #expect(await entryIter.next() == 1)

      // Release the first → it writes serverTime 1000; await it so its write lands before the second's.
      releaseConts.value[0]?.yield(())
      _ = try await first.value

      // Release the second → its stale-read write clobbers the first (serverTime 2000 wins).
      releaseConts.value[1]?.yield(())
      _ = try await second.value
    }

    #expect(callCount.value == 2, "both concurrent syncs POSTed — no in-flight guard suppressed either")
    let mark = try await watermark(db)
    #expect(
      mark?.serverTime == Date(timeIntervalSince1970: 2000),
      "last writer wins: the second sync (stale seed read) overwrote the first's watermark"
    )
    #expect(mark?.anchor == anchorString(Self.now), "both writes used the constant readInstant anchor")
  }
}
