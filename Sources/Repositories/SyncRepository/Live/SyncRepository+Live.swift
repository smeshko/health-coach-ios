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
import WireModels

extension SyncRepository: DependencyKey {
  public static let liveValue: SyncRepository = .live

  /// The sync orchestrator (ARCHITECTURE §7/§11, D11). Reads the watermark, captures the read instant,
  /// reads HK deltas, attaches the check-in (+ strength test when due), POSTs `/sync`, and **on
  /// success only** advances the watermark + stores `serverTime` in one `Database.write`. On failure
  /// the watermark is untouched (idempotent, freely retryable; zero-upsert = success).
  public static var live: SyncRepository {
    SyncRepository(sync: { try await runSync() }, lastSync: { try await runLastSync() })
  }
}

/// The last-sync time: the persisted watermark `serverTime`, or `nil` when no watermark row exists yet
/// (never synced). A single `Database.read` reusing the same `SyncWatermarkRecord` row `runSync()`
/// advances — **no** `APIClient`/`HealthKitClient` call, so opening Settings never triggers a sync.
private func runLastSync() async throws -> Date? {
  @Dependency(\.database) var database
  return try await database.read { db in
    try SyncWatermarkRecord.fetchOne(db, key: 1)?.serverTime
  }
}

// No in-flight guard: `runSync()` is a stateless free function (read watermark → POST → write
// watermark), so two concurrent calls both read the same anchor and the last writer wins — but the
// only caller, `TodayFeature`'s orchestration, runs sync under `.cancellable(cancelInFlight: true)`,
// which cancels any prior invocation, so concurrent `sync()` is not reachable in-app (single-user app).
// The behavior is characterized — not serialized — by `test_concurrentSync_lastWriterWins_noGuard`
// (SyncOrchestrationTests); see DECISIONS.md D2. A second caller would be the cue to revisit a guard.
private func runSync() async throws -> SyncResult {
  @Dependency(\.healthKitClient) var healthKit
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.strengthTestRepository) var strengthTestRepository
  @Dependency(\.date) var date
  @Dependency(\.continuousClock) var clock

  // 1. Resolve the watermark; an absent row (first-ever sync) → a default with no anchor → backfill.
  let existing = try await database.read { db in
    try SyncWatermarkRecord.fetchOne(db, key: 1)
  } ?? SyncWatermarkRecord(anchor: nil, serverTime: Date(timeIntervalSince1970: 0))

  // 2. Capture the read instant BEFORE the HK read, so the watermark advance can't skip samples that
  //    land during the in-flight POST (DECISIONS #1; at worst re-sent — sync is idempotent).
  let readInstant = date.now

  // 3. HK deltas since the anchor. HK-unavailable/partial degrades to an empty set inside the client.
  //    Bounded by `healthReadTimeout` (CR-3): `HKSampleQuery`/`HKActivitySummaryQuery` are callback-based
  //    and ignore cancellation, so a wedged `healthd` would otherwise pin the `.syncing` screen open with
  //    no automatic recovery (the Cancel button is the manual escape). On timeout this throws BEFORE the
  //    watermark write below, so the unread window is simply re-read on the next sync — no data loss.
  let anchor = existing.anchor
  let samples = try await withSyncTimeout(healthReadTimeout, clock: clock) {
    try await healthKit.deltaSamples(anchorDate(anchor))
  }

  // 4. Today's check-in (a read failure degrades to nil — the check-in is optional) + the strength
  //    test only when due.
  let today = readInstant
  let checkin = try? await checkInRepository.current(today)
  let currentWeek = ISOWeek.current
  // The gate decides due-ness on the test's *own* date (must be in the current ISO week); the payload
  // is then sent with **today's date** — the app sends the numbers dated today and the server derives
  // the ISO week (PRD §7.3).
  let strengthTest = try await dueStrengthTest(
    strengthTestRepository,
    today: today,
    currentWeek: currentWeek,
    lastSyncedWeek: existing.lastStrengthTestSyncedWeek
  ).map { DomainModels.StrengthTest(date: today, maxPushups: $0.maxPushups, maxPullups: $0.maxPullups) }

  // 5. Build the request.
  let request = buildSyncRequest(samples: samples, checkin: checkin, strengthTest: strengthTest)

  // 6. POST. A 401 propagates as the raw `APIError` (session-stream-handled); other errors → SyncError.
  let response: SyncResponse
  do {
    response = try await apiClient.sync(request)
  } catch let apiError as APIError {
    if isUnauthorized(apiError) { throw apiError }
    throw syncError(apiError)
  }

  // 7. Success only: advance the watermark + store serverTime + (if a strength test was attached) the
  //    year-qualified ISO-week marker — in one write. Upsert builds the singleton if none existed.
  try await database.write { db in
    let updated = SyncWatermarkRecord(
      anchor: anchorString(readInstant),
      serverTime: response.serverTime,
      lastStrengthTestSyncedWeek: strengthTest != nil ? currentWeek : existing.lastStrengthTestSyncedWeek
    )
    try updated.save(db)
  }

  return syncResult(response)
}

/// The strength test to attach, or `nil` when not due. Due = not already synced this ISO week **and**
/// the latest test's own `date` falls in the current ISO week (never attach a stale prior-week value —
/// the server keys by ISO week off today's date, PRD §7.3).
private func dueStrengthTest(
  _ repository: StrengthTestRepository,
  today: Date,
  currentWeek: ISOWeek,
  lastSyncedWeek: ISOWeek?
) async throws -> DomainModels.StrengthTest? {
  guard lastSyncedWeek != currentWeek else { return nil }
  guard let test = try await repository.current(today) else { return nil }
  guard ISOWeek.containing(test.date) == currentWeek else { return nil }
  return test
}

/// First-sync backfill floor. The first-ever sync would otherwise read from `.distantPast` and upload
/// the device's entire HealthKit history; instead it uploads only entries on/after this cutoff. Later
/// syncs anchor to the last read instant (always newer than the floor) and are unaffected.
/// 2026-05-23 00:00 Europe/Sofia — earlier history was exported separately and is intentionally skipped.
let backfillFloor = Date(timeIntervalSince1970: 1_779_483_600)

/// The HK read anchor as a `Date`. The watermark stores it as a lossless `timeIntervalSince1970`
/// string (the 2.3 record's `anchor` column is `String?`); an absent/garbage value → the
/// `backfillFloor` (first-ever sync backfills bounded historical data, PRD §7.1).
func anchorDate(_ string: String?) -> Date {
  guard let string, let interval = TimeInterval(string) else { return backfillFloor }
  return Date(timeIntervalSince1970: interval)
}

/// Serialize a read instant for the watermark's `String?` `anchor` column (lossless round-trip).
func anchorString(_ date: Date) -> String {
  String(date.timeIntervalSince1970)
}

/// How long the HealthKit delta read may run before the sync gives up (CR-3, release audit 2026-06-18).
/// Generous enough that a normal — even first-of-the-day — read never trips it, tight enough that a
/// wedged HealthKit can't pin the `.syncing` screen open forever. The in-screen Cancel button is the
/// immediate manual escape; this is the automatic backstop.
let healthReadTimeout: Duration = .seconds(20)

/// Run `operation`, but give up after `duration` and throw `SyncError.transient` rather than awaiting
/// forever (CR-3). HealthKit's sample/activity queries are callback-based and **ignore task
/// cancellation**, so cancelling the surrounding task can't unblock a wedged read. This races the
/// operation against a clock sleep and **abandons** a still-running operation on timeout: whichever
/// finishes first resumes the continuation (guarded so the other's late result is dropped), so the call
/// returns even though the underlying read can't be cancelled. The injected `clock` keeps it
/// deterministic under test (advance a `TestClock` past `duration` to force the timeout branch).
func withSyncTimeout<T: Sendable>(
  _ duration: Duration,
  clock: any Clock<Duration>,
  _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  let flag = ResumeOnceFlag()
  return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
    Task {
      do {
        let value = try await operation()
        if flag.claim() { continuation.resume(returning: value) }
      } catch {
        if flag.claim() { continuation.resume(throwing: error) }
      }
    }
    Task {
      // A cancelled sleep (the success path never advances this clock) just leaves the operation task to
      // resume the continuation — so swallow the cancellation rather than racing a second resume.
      guard (try? await clock.sleep(for: duration)) != nil else { return }
      if flag.claim() { continuation.resume(throwing: SyncError.transient) }
    }
  }
}

/// A one-shot guard so exactly one of the two racing tasks in `withSyncTimeout` resumes the continuation
/// (a double-resume traps). Foundation `NSLock` mirrors `DevSettingsStore`'s in-process locking; the
/// `@unchecked Sendable` is sound because every access goes through that lock.
private final class ResumeOnceFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var claimed = false
  /// True for the first caller only; false thereafter.
  func claim() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if claimed { return false }
    claimed = true
    return true
  }
}
