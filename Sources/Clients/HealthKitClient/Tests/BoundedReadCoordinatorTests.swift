import Clocks
import Foundation
import Testing

@testable import HealthKitClient

/// Records the coordinator's stopped-queries instrumentation callback.
private final class StopRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var _counts: [Int] = []

  var counts: [Int] {
    lock.lock()
    defer { lock.unlock() }
    return _counts
  }

  func record(_ count: Int) {
    lock.lock()
    defer { lock.unlock() }
    _counts.append(count)
  }
}

/// Pins `BoundedReadCoordinator` (Phase 18.2 validation round-3 #2) with fake handles + a
/// `TestClock`: timeout → `.timedOut` + every registered handle stopped exactly once; caller
/// cancellation stops the in-flight queries too; the success path neither stops nor times out.
struct BoundedReadCoordinatorTests {
  private struct Read {
    let handle: FakeQueryHandle
    let lifecycle: QueryLifecycle<FakeQueryHandle, Int>
  }

  /// N reads whose fake queries never call back — the shape of a wedged HealthKit store.
  private static func neverFinishingReads(_ count: Int) -> [Read] {
    (0..<count).map { _ in Read(handle: FakeQueryHandle(), lifecycle: QueryLifecycle()) }
  }

  private static func operations(for reads: [Read]) -> [@Sendable () async throws -> Int] {
    reads.map { read in
      { try await read.lifecycle.run(makeHandle: { read.handle }, execute: { $0.executed() }) }
    }
  }

  @Test func test_timeout_throwsTimedOut_andStopsEveryRegisteredHandleExactlyOnce() async {
    let clock = TestClock()
    let recorder = StopRecorder()
    let reads = Self.neverFinishingReads(3)

    let task = Task {
      try await BoundedReadCoordinator.run(
        lifecycles: reads.map(\.lifecycle),
        timeout: .seconds(15),
        clock: clock,
        onQueriesStopped: { recorder.record($0) },
        operations: Self.operations(for: reads)
      )
    }
    // Only advance once every fake query is genuinely in flight (registered + executed).
    for read in reads {
      while read.handle.executeCount == 0 { await Task.yield() }
    }
    await clock.advance(by: .seconds(15))
    let result = await task.result

    guard case .failure(let error) = result else {
      Issue.record("expected the timeout to throw")
      return
    }
    #expect(error as? HealthKitReadError == .timedOut)
    for read in reads {
      #expect(read.handle.stopCount == 1, "every in-flight query stopped exactly once")
    }
    #expect(recorder.counts == [3], "one instrumentation callback with the stopped count")
  }

  @Test func test_callerCancellation_stopsInFlightQueries_andRethrowsCancellation() async {
    let clock = TestClock()
    let recorder = StopRecorder()
    let reads = Self.neverFinishingReads(2)

    let task = Task {
      try await BoundedReadCoordinator.run(
        lifecycles: reads.map(\.lifecycle),
        timeout: .seconds(15),
        clock: clock,
        onQueriesStopped: { recorder.record($0) },
        operations: Self.operations(for: reads)
      )
    }
    for read in reads {
      while read.handle.executeCount == 0 { await Task.yield() }
    }
    task.cancel()
    let result = await task.result

    #expect(throwsCancellation(result), "a cancelled read can never complete as success")
    for read in reads {
      #expect(read.handle.stopCount == 1, "caller cancellation reaches every live query")
    }
    #expect(recorder.counts == [2])
  }

  @Test func test_allReadsComplete_returnsEveryOutput_withoutStoppingAnything() async throws {
    let clock = TestClock()
    let recorder = StopRecorder()
    let reads = Self.neverFinishingReads(3)

    // Each fake query "calls back" immediately on execute, like a fast healthy read.
    let operations: [@Sendable () async throws -> Int] = reads.enumerated().map { index, read in
      {
        try await read.lifecycle.run(
          makeHandle: { read.handle },
          execute: { started in
            started.executed()
            read.lifecycle.finish(index)
          }
        )
      }
    }

    let outputs = try await BoundedReadCoordinator.run(
      lifecycles: reads.map(\.lifecycle),
      timeout: .seconds(15),
      clock: clock,
      onQueriesStopped: { recorder.record($0) },
      operations: operations
    )

    #expect(outputs.sorted() == [0, 1, 2], "every read's output is returned")
    for read in reads {
      #expect(read.handle.stopCount == 0, "a completed read never stops its query")
    }
    #expect(recorder.counts.isEmpty, "no instrumentation on the success path")
  }

  @Test func test_timeoutBeforeAnyRegistration_stillThrowsTimedOut_withZeroStops() async {
    let clock = TestClock()
    let recorder = StopRecorder()
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let handle = FakeQueryHandle()
    let gate = TestClock()

    // Held before registration: the read thunk is still waiting when the timeout fires, so the
    // lifecycle must refuse the (never-attempted) registration path entirely.
    let heldOperation: @Sendable () async throws -> Int = {
      try await gate.sleep(for: .seconds(1))
      return try await lifecycle.run(makeHandle: { handle }, execute: { $0.executed() })
    }
    let task = Task {
      try await BoundedReadCoordinator.run(
        lifecycles: [lifecycle],
        timeout: .seconds(15),
        clock: clock,
        onQueriesStopped: { recorder.record($0) },
        operations: [heldOperation]
      )
    }
    await clock.advance(by: .seconds(15))
    let result = await task.result

    guard case .failure(let error) = result else {
      Issue.record("expected the timeout to throw")
      return
    }
    #expect(error as? HealthKitReadError == .timedOut)
    #expect(handle.executeCount == 0, "cancel-before-registration never executes the query")
    #expect(handle.stopCount == 0)
    #expect(recorder.counts == [0], "nothing was in flight, so nothing was stopped")
  }
}
