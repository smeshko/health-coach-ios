import Dependencies
import Foundation

/// The sync orchestrator seam (ARCHITECTURE §7, §11, D11). A `Sendable` struct with a single
/// **argument-free** `sync()` closure — the repository owns the watermark, the HealthKit read window,
/// and the inputs, so callers (the app-open effect, §11) just invoke it. `.live` (HK + network + GRDB)
/// and `.mock(scenario:)` live in `SyncRepositoryLive`.
public struct SyncRepository: Sendable {
  public var sync: @Sendable () async throws -> SyncResult

  public init(sync: @escaping @Sendable () async throws -> SyncResult) {
    self.sync = sync
  }
}

extension SyncRepository: TestDependencyKey {
  /// A canned successful, zero-upsert result — no live dependency.
  public static var testValue: SyncRepository {
    SyncRepository(sync: { Self.cannedResult })
  }

  public static var previewValue: SyncRepository {
    testValue
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
