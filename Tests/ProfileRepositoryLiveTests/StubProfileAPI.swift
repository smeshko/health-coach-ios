import APIClient
import Foundation
import WireModels

/// A lock-guarded stub for `APIClient.profile`. Counts calls and returns a canned `ProfileResponse`
/// or throws an `APIError`. Other routes trap.
final class StubProfileAPI: @unchecked Sendable {
  private let lock = NSLock()
  private var _callCount = 0
  let result: Result<ProfileResponse, APIError>

  init(result: Result<ProfileResponse, APIError>) {
    self.result = result
  }

  var callCount: Int { lock.withLock { _callCount } }

  func makeClient() -> APIClient {
    APIClient(
      health: { fatalError("unused") },
      probe: { fatalError("unused") },
      sync: { _ in fatalError("unused") },
      dailyBrief: { _, _ in fatalError("unused") },
      weeklyBrief: { _, _ in fatalError("unused") },
      profile: { [self] in
        lock.withLock { _callCount += 1 }
        return try result.get()
      },
      sessionEvents: { AsyncStream { $0.finish() } }
    )
  }
}
