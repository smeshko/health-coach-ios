import APIClient
import Foundation
import WireModels

// Shared APIClient test stub (Phase 11.6 / DECISIONS D1). Replaces the three hand-rolled
// per-target stubs (`StubAPIClient`, `StubProfileAPI`, the API-stub core of `SyncStubs`). Lives
// OUTSIDE the `#if canImport(UIKit)` guard of this target: it is Foundation + the APIClient
// interface (both host-compiling), with no UIKit/SnapshotTesting import.

public extension APIClient {
  /// An `APIClient` whose every route **fails** unless explicitly overridden. Pass a closure for
  /// each route a test exercises; the rest throw `APIError.unexpectedStatus(0)` if called (the same
  /// "must not be called here" contract the old per-target stubs encoded with `fatalError`, but as a
  /// thrown error so a stray call surfaces as a test failure rather than a process trap).
  ///
  /// To RECORD calls (the old `StubAPIClient` counters / `lastWeeklyArg` capture), have the override
  /// closure write into a `CallRecorder` (or any test-owned reference) before returning — see
  /// `CallRecorder`.
  static func failing(
    probe: (@Sendable () async throws -> Bool)? = nil,
    sync: (@Sendable (SyncRequest) async throws -> SyncResponse)? = nil,
    dailyBrief: (@Sendable (_ date: Date?, _ refresh: Bool) async throws -> DailyBrief)? = nil,
    weeklyBrief: (@Sendable (_ isoWeek: String?, _ refresh: Bool) async throws -> WeeklyPlan)? = nil,
    profile: (@Sendable () async throws -> ProfileResponse)? = nil,
    sessionEvents: (@Sendable () -> AsyncStream<SessionEvent>)? = nil
  ) -> APIClient {
    APIClient(
      probe: probe ?? { throw APIError.unexpectedStatus(0) },
      sync: sync ?? { _ in throw APIError.unexpectedStatus(0) },
      dailyBrief: dailyBrief ?? { _, _ in throw APIError.unexpectedStatus(0) },
      weeklyBrief: weeklyBrief ?? { _, _ in throw APIError.unexpectedStatus(0) },
      profile: profile ?? { throw APIError.unexpectedStatus(0) },
      sessionEvents: sessionEvents ?? { AsyncStream { $0.finish() } }
    )
  }
}

/// A lock-guarded recorder for stub routes: a test increments `count` and stashes the last argument
/// of whatever route it cares about. This replaces the bespoke `_dailyCallCount` / `_lastWeeklyArg`
/// fields that the old per-target stubs carried — generic over the captured argument type.
public final class CallRecorder<Argument: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0
  private var _lastArgument: Argument?

  public init() {}

  /// Record one invocation, stashing its argument.
  public func record(_ argument: Argument) {
    lock.withLock {
      _count += 1
      _lastArgument = argument
    }
  }

  public var count: Int { lock.withLock { _count } }
  public var lastArgument: Argument? { lock.withLock { _lastArgument } }
}
