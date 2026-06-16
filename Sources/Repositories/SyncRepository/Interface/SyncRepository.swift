import Dependencies
import Foundation

/// The sync orchestrator seam (ARCHITECTURE §7, §11, D11). A `Sendable` struct with a single
/// **argument-free** `sync()` closure — the repository owns the watermark, the HealthKit read window,
/// and the inputs, so callers (the app-open effect, §11) just invoke it. `.live` (HK + network + GRDB)
/// and `.mock(scenario:)` live in `SyncRepositoryLive`.
public struct SyncRepository: Sendable {
  public var sync: @Sendable () async throws -> SyncResult
  /// Read-only last-sync time — the persisted watermark `serverTime`, or `nil` when never synced. A
  /// cache read (`Database.read`) with **no** network round-trip, so a passive surface like Settings
  /// can show "last sync" without triggering a sync (Phase 10.2 DECISIONS #1).
  public var lastSync: @Sendable () async throws -> Date?

  public init(
    sync: @escaping @Sendable () async throws -> SyncResult,
    lastSync: @escaping @Sendable () async throws -> Date? = { nil }
  ) {
    self.sync = sync
    self.lastSync = lastSync
  }
}

extension SyncRepository: TestDependencyKey {
  /// A canned successful, zero-upsert result + a canned last-sync time — no live dependency.
  public static var testValue: SyncRepository {
    SyncRepository(sync: { Self.cannedResult }, lastSync: { Self.cannedLastSync })
  }

  public static var previewValue: SyncRepository {
    testValue
  }

  /// 2026-06-08 ~09:00 Europe/Sofia — a fixed canned last-sync instant for test/preview values.
  static var cannedLastSync: Date? {
    Date(timeIntervalSince1970: 1_780_898_400)
  }

  static var cannedResult: SyncResult {
    SyncResult(
      recordsUpserted: 0,
      recordsDuplicate: 0,
      workoutsUpserted: 0,
      activityDaysUpserted: 0,
      checkinSaved: false,
      strengthTestSaved: false,
      serverTime: Date(timeIntervalSince1970: 0)
    )
  }
}

public extension DependencyValues {
  var syncRepository: SyncRepository {
    get { self[SyncRepository.self] }
    set { self[SyncRepository.self] = newValue }
  }
}
