import Foundation

/// Races N lifecycle-driven read operations against one whole-read timeout (Phase 18.2 validation
/// round-3 #2 — the race is a host-testable coordinator, not inline task-group code in the live
/// client). On timeout it cancels every lifecycle — stopping each registered query handle exactly
/// once — and throws `HealthKitReadError.timedOut`; caller cancellation takes the same
/// stop-everything path and rethrows `CancellationError`. Either way `onQueriesStopped` fires once
/// with the number of in-flight queries actually stopped (the epic's show-it-stopping
/// instrumentation); the success path never calls it.
public enum BoundedReadCoordinator {
  public static func run<Output: Sendable>(
    lifecycles: [any QueryCancelling],
    timeout: Duration,
    clock: any Clock<Duration>,
    onQueriesStopped: @escaping @Sendable (Int) -> Void,
    operations: [@Sendable () async throws -> Output]
  ) async throws -> [Output] {
    do {
      return try await race(operations: operations, timeout: timeout, clock: clock)
    } catch {
      // Timeout or cancellation: make sure EVERY lifecycle is cancelled (idempotent — the ones the
      // task-group cancellation already reached are no-ops), then report how many live queries
      // were stopped in total.
      for lifecycle in lifecycles {
        lifecycle.cancel()
      }
      onQueriesStopped(lifecycles.count { $0.handleWasStopped })
      throw error
    }
  }

  private enum RaceSlot<Output: Sendable>: Sendable {
    case output(Output)
    case deadline
  }

  private static func race<Output: Sendable>(
    operations: [@Sendable () async throws -> Output],
    timeout: Duration,
    clock: any Clock<Duration>
  ) async throws -> [Output] {
    try await withThrowingTaskGroup(of: RaceSlot<Output>.self) { group in
      for operation in operations {
        group.addTask { try await .output(operation()) }
      }
      group.addTask {
        try await clock.sleep(for: timeout)
        return .deadline
      }
      var outputs: [Output] = []
      outputs.reserveCapacity(operations.count)
      while outputs.count < operations.count {
        switch try await group.next() {
        case .output(let value):
          outputs.append(value)
        case .deadline:
          // Throwing out of the body cancels the group: the read operations observe it via their
          // lifecycles (→ `stop`), and the caller's `catch` converts the sweep into the count.
          throw HealthKitReadError.timedOut
        case nil:
          // Unreachable: the deadline task outlives the reads, so `next()` cannot run dry first.
          throw CancellationError()
        }
      }
      // Every read completed — retire the still-sleeping deadline task.
      group.cancelAll()
      return outputs
    }
  }
}
