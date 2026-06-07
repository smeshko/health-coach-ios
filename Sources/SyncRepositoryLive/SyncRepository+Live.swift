import APIClient
import CheckInRepository
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import HealthKitClient
import PersistenceModels
import StrengthTestRepository
import SyncRepository
import WireModels

extension SyncRepository: DependencyKey {
  public static let liveValue: SyncRepository = .live

  /// The sync orchestrator (ARCHITECTURE §7/§11, D11). Reads the watermark, captures the read instant,
  /// reads HK deltas, attaches the check-in (+ strength test when due), POSTs `/sync`, and **on
  /// success only** advances the watermark + stores `serverTime` in one `Database.write`. On failure
  /// the watermark is untouched (idempotent, freely retryable; zero-upsert = success).
  public static var live: SyncRepository {
    SyncRepository(sync: { try await runSync() })
  }
}

private func runSync() async throws -> SyncResult {
  @Dependency(\.healthKitClient) var healthKit
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.strengthTestRepository) var strengthTestRepository
  @Dependency(\.date) var date

  // 1. Resolve the watermark; an absent row (first-ever sync) → a default with no anchor → backfill.
  let existing = try await database.read { db in
    try SyncWatermarkRecord.fetchOne(db, key: 1)
  } ?? SyncWatermarkRecord(anchor: nil, serverTime: Date(timeIntervalSince1970: 0))

  // 2. Capture the read instant BEFORE the HK read, so the watermark advance can't skip samples that
  //    land during the in-flight POST (DECISIONS #1; at worst re-sent — sync is idempotent).
  let readInstant = date.now

  // 3. HK deltas since the anchor. HK-unavailable/partial degrades to an empty set inside the client.
  let samples = try await healthKit.deltaSamples(anchorDate(existing.anchor))

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

/// The HK read anchor as a `Date`. The watermark stores it as a lossless `timeIntervalSince1970`
/// string (the 2.3 record's `anchor` column is `String?`); an absent/garbage value → `.distantPast`
/// (first-ever sync backfills historical data, PRD §7.1).
func anchorDate(_ string: String?) -> Date {
  guard let string, let interval = TimeInterval(string) else { return .distantPast }
  return Date(timeIntervalSince1970: interval)
}

/// Serialize a read instant for the watermark's `String?` `anchor` column (lossless round-trip).
func anchorString(_ date: Date) -> String {
  String(date.timeIntervalSince1970)
}
