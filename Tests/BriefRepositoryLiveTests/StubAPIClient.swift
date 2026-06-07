import APIClient
import Foundation
import WireModels

/// A lock-guarded recording stub for `APIClient`. Counts `dailyBrief`/`weeklyBrief` calls and serves
/// a canned DTO or throws a canned `APIError`. Only the brief routes are exercised here; the rest
/// trap if called.
final class StubAPIClient: @unchecked Sendable {
  private let lock = NSLock()
  private var _dailyCallCount = 0
  private var _weeklyCallCount = 0
  private var _lastDailyRefresh: Bool?
  private var _lastWeeklyRefresh: Bool?
  private var _lastWeeklyArg: String??

  /// What `dailyBrief` should do: return a DTO or throw.
  var dailyResult: Result<WireModels.DailyBrief, APIError>
  /// What `weeklyBrief` should do.
  var weeklyResult: Result<WireModels.WeeklyPlan, APIError>

  init(
    dailyResult: Result<WireModels.DailyBrief, APIError> = .failure(.unexpectedStatus(0)),
    weeklyResult: Result<WireModels.WeeklyPlan, APIError> = .failure(.unexpectedStatus(0))
  ) {
    self.dailyResult = dailyResult
    self.weeklyResult = weeklyResult
  }

  var dailyCallCount: Int { lock.withLock { _dailyCallCount } }
  var weeklyCallCount: Int { lock.withLock { _weeklyCallCount } }
  var lastDailyRefresh: Bool? { lock.withLock { _lastDailyRefresh } }
  var lastWeeklyRefresh: Bool? { lock.withLock { _lastWeeklyRefresh } }
  var lastWeeklyArg: String?? { lock.withLock { _lastWeeklyArg } }

  /// Build an `APIClient` whose brief routes hit this stub; other routes trap.
  func makeClient() -> APIClient {
    APIClient(
      health: { unimplemented("health") },
      probe: { unimplemented("probe") },
      sync: { _ in unimplemented("sync") },
      dailyBrief: { [self] _, refresh in
        lock.withLock {
          _dailyCallCount += 1
          _lastDailyRefresh = refresh
        }
        return try dailyResult.get()
      },
      weeklyBrief: { [self] isoWeek, refresh in
        lock.withLock {
          _weeklyCallCount += 1
          _lastWeeklyRefresh = refresh
          _lastWeeklyArg = isoWeek
        }
        return try weeklyResult.get()
      },
      profile: { unimplemented("profile") },
      sessionEvents: { .finished }
    )
  }
}

private func unimplemented(_ route: String) -> Never {
  fatalError("StubAPIClient route '\(route)' must not be called in these tests")
}

private extension AsyncStream {
  /// An immediately-finished stream for the unused `sessionEvents` route.
  static var finished: AsyncStream<Element> {
    AsyncStream { $0.finish() }
  }
}
