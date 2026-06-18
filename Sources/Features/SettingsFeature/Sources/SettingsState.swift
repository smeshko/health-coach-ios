import DomainModels
import Foundation

/// The production state slices for the You-tab Settings surface (Phase 10.2). Modelled as plain
/// `Equatable` value slices on the one `SettingsFeature` reducer (DECISIONS #5) — read-only display
/// surfaces sharing one `onAppear` load, no independent navigation.
public extension SettingsFeature {
  /// The screen-level load lifecycle so the view can show a skeleton / inline error while the repos
  /// resolve. `.loaded` is reached only once all four slices have resolved and none failed.
  enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
  }

  /// The coach-connection state, derived from `TokenClient.read()` (non-nil ⇒ connected). Only the
  /// **last-4 masked suffix** is held — never the full bearer token (DECISIONS #4).
  enum ConnectionStatus: Equatable, Sendable {
    case unknown
    case connected(tokenSuffix: String)
    case notConnected
  }

  struct ConnectionState: Equatable, Sendable {
    public var status: ConnectionStatus
    public init(status: ConnectionStatus = .unknown) {
      self.status = status
    }
  }

  /// The last-sync time (the watermark `serverTime`); `nil` ⇒ "Never synced".
  struct LastSyncState: Equatable, Sendable {
    public var lastSyncAt: Date?
    public init(lastSyncAt: Date? = nil) {
      self.lastSyncAt = lastSyncAt
    }
  }

  /// The read-only, coach-managed profile constants. VO₂max is **omitted** — it is not a `/profile`
  /// field (DECISIONS #6).
  struct ConstantsState: Equatable, Sendable {
    public var age: Int?
    public var zones: DomainModels.Zones?
    public var restingHrBpm: Int?
    public var hrvBaselineMs: Int?
    public var recomputeNoticeWeek: String?

    public init(
      age: Int? = nil,
      zones: DomainModels.Zones? = nil,
      restingHrBpm: Int? = nil,
      hrvBaselineMs: Int? = nil,
      recomputeNoticeWeek: String? = nil
    ) {
      self.age = age
      self.zones = zones
      self.restingHrBpm = restingHrBpm
      self.hrvBaselineMs = hrvBaselineMs
      self.recomputeNoticeWeek = recomputeNoticeWeek
    }
  }

  /// A feature-local opaque error so the reducer never holds the repo's `ProfileRepositoryError`.
  enum ProfileLoadFailure: Error, Equatable, Sendable {
    case failed
  }
}
