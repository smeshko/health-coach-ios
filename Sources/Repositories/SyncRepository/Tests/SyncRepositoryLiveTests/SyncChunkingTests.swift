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

/// The chunked-backfill window math and orchestration (audit follow-up: the Phase 18.2 per-type
/// row cap silently truncated the first-sync backfill to its newest ~10k samples per type; long
/// windows are now several bounded `[start, until)` reads + POSTs instead of one).
struct SyncWindowsTests {
  private let base = Date(timeIntervalSince1970: 1_779_483_600) // the backfill floor
  private let week: TimeInterval = 7 * 24 * 60 * 60

  @Test func test_shortWindow_isSingleOpenToppedWindow() {
    let windows = syncWindows(from: base, to: base.addingTimeInterval(week - 1))
    #expect(windows.count == 1)
    #expect(windows[0].start == base)
    #expect(windows[0].until == nil)
  }

  /// A span of exactly one chunk stays a single window — the final window is always open-topped,
  /// so the everyday delta is byte-identical to the pre-chunking read.
  @Test func test_exactChunkSpan_isSingleWindow() {
    let windows = syncWindows(from: base, to: base.addingTimeInterval(week))
    #expect(windows.count == 1)
    #expect(windows[0].until == nil)
  }

  @Test func test_longWindow_chunksAreContiguous_halfOpen_finalOpenTopped() {
    // 16.4 days ≈ the May-23-floor → June-8 fixture span: 2 bounded chunks + the open-topped tail.
    let windows = syncWindows(from: base, to: base.addingTimeInterval(week * 2.34))
    #expect(windows.count == 3)
    #expect(windows[0].start == base)
    #expect(windows[0].until == base.addingTimeInterval(week))
    #expect(windows[1].start == base.addingTimeInterval(week))
    #expect(windows[1].until == base.addingTimeInterval(week * 2))
    #expect(windows[2].start == base.addingTimeInterval(week * 2))
    #expect(windows[2].until == nil)
  }

  @Test func test_degenerateWindow_toBeforeFrom_isSingleOpenToppedWindow() {
    let windows = syncWindows(from: base, to: base.addingTimeInterval(-100))
    #expect(windows.count == 1)
    #expect(windows[0].until == nil)
  }
}

/// End-to-end chunked orchestration over the in-memory database: per-chunk reads/POSTs, empty-chunk
/// skipping, final-chunk-only check-in, aggregation, and the single watermark advance at the end.
struct SyncChunkedOrchestrationTests {
  /// 2026-06-08 ~09:00 Europe/Sofia — 16.4 days after the backfill floor → 3 windows.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  /// Records every read's bounds and serves per-call sample sets; the API stub records every
  /// request and serves per-call responses.
  private final class ChunkStubs: @unchecked Sendable {
    let boundsRecorder = CallRecorderList<HealthReadBounds>()
    let requestRecorder = CallRecorderList<SyncRequest>()
    let samplesPerCall: [HealthSampleSet]
    let responsesPerCall: [SyncResponse]
    let checkin: DomainModels.CheckIn?

    init(samplesPerCall: [HealthSampleSet], responsesPerCall: [SyncResponse], checkin: DomainModels.CheckIn? = nil) {
      self.samplesPerCall = samplesPerCall
      self.responsesPerCall = responsesPerCall
      self.checkin = checkin
    }

    func healthKit() -> HealthKitClient {
      HealthKitClient(
        isHealthDataAvailable: { true },
        requestAuthorization: {},
        authorizationStatus: { [:] },
        deltaSamples: { [self] bounds in
          let index = boundsRecorder.count
          boundsRecorder.record(bounds)
          return index < samplesPerCall.count ? samplesPerCall[index] : HealthSampleSet()
        }
      )
    }

    func api() -> APIClient {
      .failing(sync: { [self] request in
        let index = requestRecorder.count
        requestRecorder.record(request)
        return responsesPerCall[min(index, responsesPerCall.count - 1)]
      })
    }
  }

  /// Thread-safe append-only recorder (the shared `CallRecorder` keeps only the last argument).
  final class CallRecorderList<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []
    var count: Int { lock.lock(); defer { lock.unlock() }; return values.count }
    var all: [Value] { lock.lock(); defer { lock.unlock() }; return values }
    func record(_ value: Value) { lock.lock(); values.append(value); lock.unlock() }
  }

  private func run<T>(
    stubs: ChunkStubs, database: DatabaseClient, _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.continuousClock = TestClock()
      $0.healthKitClient = stubs.healthKit()
      $0.apiClient = stubs.api()
      $0.database = database
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { [stubs] _ in stubs.checkin })
      $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
    } operation: {
      try await work()
    }
  }

  private func record(_ uuid: String) -> HealthRecordPayload {
    HealthRecordPayload(uuid: uuid, type: .heartRate, start: Self.now, end: Self.now, value: 60)
  }

  @Test func test_firstSync_chunksWindows_aggregates_advancesWatermarkOnce() async throws {
    let db = try DatabaseClient.makeInMemory()
    let checkin = DomainModels.CheckIn(date: Self.now, giSymptoms: false, kneePain: 0, illness: false)
    let stubs = ChunkStubs(
      samplesPerCall: [
        HealthSampleSet(records: [record("a")]),
        HealthSampleSet(records: [record("b")]),
        HealthSampleSet(records: [record("c")]),
      ],
      responsesPerCall: [
        syncResponse(recordsUpserted: 1, serverTime: Date(timeIntervalSince1970: 1000)),
        syncResponse(recordsUpserted: 2, serverTime: Date(timeIntervalSince1970: 2000)),
        syncResponse(recordsUpserted: 4, checkinSaved: true, serverTime: Date(timeIntervalSince1970: 3000)),
      ],
      checkin: checkin
    )

    let result = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    // Three contiguous half-open windows from the backfill floor; the final one open-topped.
    let bounds = stubs.boundsRecorder.all
    #expect(bounds.count == 3)
    #expect(bounds[0].since == backfillFloor)
    #expect(bounds[0].until == bounds[1].since)
    #expect(bounds[1].until == bounds[2].since)
    #expect(bounds[2].until == nil)

    // Check-in rides ONLY the final chunk's request.
    let requests = stubs.requestRecorder.all
    #expect(requests.count == 3)
    #expect(requests[0].checkin == nil)
    #expect(requests[1].checkin == nil)
    #expect(requests[2].checkin != nil)

    // Aggregated result: counts sum, flags OR, serverTime = the final response's.
    #expect(result.recordsUpserted == 7)
    #expect(result.checkinSaved)
    #expect(result.serverTime == Date(timeIntervalSince1970: 3000))

    // One watermark advance, at the end, to the read instant + final serverTime.
    let mark = try await db.read { dbx in try SyncWatermarkRecord.fetchOne(dbx, key: 1) }
    #expect(mark?.anchor == anchorString(Self.now))
    #expect(mark?.serverTime == Date(timeIntervalSince1970: 3000))
  }

  @Test func test_emptyNonFinalChunks_skipped_finalAlwaysPosts() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = ChunkStubs(
      samplesPerCall: [HealthSampleSet(), HealthSampleSet(), HealthSampleSet()],
      responsesPerCall: [syncResponse(serverTime: Date(timeIntervalSince1970: 9000))]
    )

    let result = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    // All three windows read, but only the final (always-POSTed) chunk hit the API.
    #expect(stubs.boundsRecorder.count == 3)
    #expect(stubs.requestRecorder.count == 1)
    #expect(result.recordsUpserted == 0)
    #expect(result.serverTime == Date(timeIntervalSince1970: 9000))
  }

  @Test func test_midChunkFailure_leavesWatermarkUntouched() async throws {
    let db = try DatabaseClient.makeInMemory()
    let failing = ChunkStubs(
      samplesPerCall: [
        HealthSampleSet(records: [record("a")]),
        HealthSampleSet(records: [record("b")]),
        HealthSampleSet(records: [record("c")]),
      ],
      responsesPerCall: [syncResponse()]
    )
    // Fail the SECOND POST: first chunk lands, then the loop must abort pre-watermark.
    let posts = CallRecorderList<SyncRequest>()
    let api = APIClient.failing(sync: { request in
      posts.record(request)
      if posts.count >= 2 { throw APIError.envelope(code: .internalError, message: "", detail: nil, status: 500) }
      return syncResponse()
    })

    do {
      _ = try await withDependencies {
        $0.useEuropeSofia()
        $0.date = .constant(Self.now)
        $0.continuousClock = TestClock()
        $0.healthKitClient = failing.healthKit()
        $0.apiClient = api
        $0.database = db
        $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in nil })
        $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in nil })
      } operation: {
        try await SyncRepository.live.sync()
      }
      Issue.record("expected the mid-chunk failure to throw")
    } catch {}

    // No watermark row was ever written — the whole backfill re-runs next sync (server dedups).
    let mark = try await db.read { dbx in try SyncWatermarkRecord.fetchOne(dbx, key: 1) }
    #expect(mark == nil)
    #expect(posts.count == 2)
  }
}

/// The dev-menu anchor reset: clears ONLY the anchor; serverTime + the strength-week marker stay.
struct SyncResetWatermarkTests {
  @Test func test_resetWatermark_clearsAnchorOnly() async throws {
    let db = try DatabaseClient.makeInMemory()
    let week = ISOWeek(year: 2026, week: 23)
    let seeded = SyncWatermarkRecord(
      anchor: "1780000000.0",
      serverTime: Date(timeIntervalSince1970: 42),
      lastStrengthTestSyncedWeek: week
    )
    try await db.write { dbx in try seeded.save(dbx) }

    try await withDependencies {
      $0.database = db
    } operation: {
      try await SyncRepository.live.resetWatermark()
    }

    let mark = try await db.read { dbx in try SyncWatermarkRecord.fetchOne(dbx, key: 1) }
    #expect(mark?.anchor == nil)
    #expect(mark?.serverTime == Date(timeIntervalSince1970: 42))
    #expect(mark?.lastStrengthTestSyncedWeek == week)
  }

  @Test func test_resetWatermark_noRow_isNoop() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await withDependencies {
      $0.database = db
    } operation: {
      try await SyncRepository.live.resetWatermark()
    }
    let mark = try await db.read { dbx in try SyncWatermarkRecord.fetchOne(dbx, key: 1) }
    #expect(mark == nil)
  }
}
