import Foundation
import Testing

@testable import HealthKitClient

/// A fake `StoppableQuery` recording how often it was executed/stopped — the host-testable stand-in
/// for the live `HKQuery`+store pair (no HealthKit on the host).
final class FakeQueryHandle: StoppableQuery, @unchecked Sendable {
  private let lock = NSLock()
  private var _executeCount = 0
  private var _stopCount = 0

  var executeCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _executeCount
  }

  var stopCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _stopCount
  }

  func executed() {
    lock.lock()
    defer { lock.unlock() }
    _executeCount += 1
  }

  func stop() {
    lock.lock()
    defer { lock.unlock() }
    _stopCount += 1
  }
}

/// Records every resume a `QueryLifecycle` delivers so tests can assert the exactly-once contract.
final class ResumeRecorder<Success: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var _results: [Result<Success, any Error>] = []

  var results: [Result<Success, any Error>] {
    lock.lock()
    defer { lock.unlock() }
    return _results
  }

  func record(_ result: Result<Success, any Error>) {
    lock.lock()
    defer { lock.unlock() }
    _results.append(result)
  }
}

/// Pins the linearizable `QueryLifecycle` protocol (Phase 18.2 validation round-2 #1 / round-3 #1):
/// cancel-before-registration never executes, late callbacks are dropped, the registered handle is
/// stopped exactly once, and every path resumes exactly once.
struct QueryLifecycleTests {
  @Test func test_callbackThenCancel_keepsSuccess_andNeverStops() throws {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    #expect(lifecycle.register(handle) == .proceed)
    lifecycle.finish(7)
    #expect(lifecycle.cancel() == false, "cancel after a delivered result is a no-op")

    #expect(recorder.results.count == 1, "exactly one resume")
    #expect(try recorder.results.first?.get() == 7, "the result callback's success is kept")
    #expect(handle.stopCount == 0, "a finished query is never stopped")
    #expect(lifecycle.handleWasStopped == false)
  }

  @Test func test_cancelThenCallback_resumesCancellation_andDropsTheResult() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    #expect(lifecycle.register(handle) == .proceed)
    #expect(lifecycle.cancel() == true, "the registered handle is stopped")
    lifecycle.finish(7)

    #expect(recorder.results.count == 1, "the late callback cannot resume a second time")
    #expect(throwsCancellation(recorder.results.first), "cancellation is recorded, not success")
    #expect(handle.stopCount == 1, "stopped exactly once")
    #expect(lifecycle.handleWasStopped == true)
  }

  @Test func test_repeatedCancel_stopsTheHandleExactlyOnce() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    _ = lifecycle.register(handle)
    #expect(lifecycle.cancel() == true)
    #expect(lifecycle.cancel() == false, "a second cancel is a no-op")

    #expect(handle.stopCount == 1)
    #expect(recorder.results.count == 1, "exactly one resume across both cancels")
  }

  @Test func test_cancelBeforeRegistration_neverExecutes_andResumesCancellation() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    #expect(lifecycle.cancel() == false, "no handle registered yet, nothing to stop")
    #expect(lifecycle.register(handle) == .alreadyCancelled, "registration after cancel is refused")

    #expect(recorder.results.count == 1)
    #expect(throwsCancellation(recorder.results.first))
    #expect(handle.stopCount == 0, "a never-executed handle is never stopped")
    #expect(lifecycle.handleWasStopped == false)
  }

  @Test func test_cancelBeforeAttach_resumesTheLateContinuationImmediately() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()

    lifecycle.cancel()
    lifecycle.attach { recorder.record($0) }

    #expect(recorder.results.count == 1, "the pre-recorded cancellation fires on attach")
    #expect(throwsCancellation(recorder.results.first))
  }

  @Test func test_doubleFinish_resumesExactlyOnce() throws {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()

    lifecycle.attach { recorder.record($0) }
    _ = lifecycle.register(FakeQueryHandle())
    lifecycle.finish(1)
    lifecycle.finish(2)

    #expect(recorder.results.count == 1)
    #expect(try recorder.results.first?.get() == 1, "the first result wins")
  }

  @Test func test_run_happyPath_executesAndReturnsTheCallbackValue() async throws {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let handle = FakeQueryHandle()

    let value = try await lifecycle.run(
      makeHandle: { handle },
      execute: { started in
        started.executed()
        lifecycle.finish(42)
      }
    )

    #expect(value == 42)
    #expect(handle.executeCount == 1)
    #expect(handle.stopCount == 0)
  }

  @Test func test_run_onAnAlreadyCancelledTask_neverExecutesTheHandle() async {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let handle = FakeQueryHandle()

    let task = Task {
      // Deterministically observe cancellation before entering `run` so the
      // cancel-before-registration path is the one exercised.
      while !Task.isCancelled { await Task.yield() }
      return try await lifecycle.run(
        makeHandle: { handle },
        execute: { started in started.executed() }
      )
    }
    task.cancel()
    let result = await task.result

    #expect(throwsCancellation(result))
    #expect(handle.executeCount == 0, "a cancelled read never executes its query")
    #expect(handle.stopCount == 0, "a never-executed handle needs no stop")
  }

  // MARK: One-shot mode — long-running, caller-stopped queries (TASK-004)

  @Test func test_finishStoppingHandle_stopsExactlyOnce_andKeepsTheResult() throws {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    _ = lifecycle.register(handle)
    lifecycle.finishStoppingHandle(9)
    lifecycle.finishStoppingHandle(10)

    #expect(recorder.results.count == 1, "exactly one resume")
    #expect(try recorder.results.first?.get() == 9, "the first delivery wins")
    #expect(handle.stopCount == 1, "the long-running query is stopped exactly once on delivery")
    #expect(lifecycle.handleWasStopped == false, "a normal completion stop is NOT cleanup")
    #expect(lifecycle.stoppedHandleCount == 0, "…so it contributes 0 to the stopped count")
  }

  @Test func test_finishStoppingHandle_afterCancel_isDropped_withoutDoubleStop() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { recorder.record($0) }
    _ = lifecycle.register(handle)
    #expect(lifecycle.cancel() == true)
    lifecycle.finishStoppingHandle(9)

    #expect(recorder.results.count == 1)
    #expect(throwsCancellation(recorder.results.first), "cancellation is kept, not success")
    #expect(handle.stopCount == 1, "the cancel's stop is the only stop — never two")
    #expect(lifecycle.stoppedHandleCount == 1, "the cleanup stop still counts")
  }

  @Test func test_cancelAfterFinishStoppingHandle_isANoOp() {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let handle = FakeQueryHandle()

    lifecycle.attach { _ in }
    _ = lifecycle.register(handle)
    lifecycle.finishStoppingHandle(9)

    #expect(lifecycle.cancel() == false, "a delivered one-shot cannot be cancelled")
    #expect(handle.stopCount == 1)
    #expect(lifecycle.stoppedHandleCount == 0)
  }

  @Test func test_run_cancelledMidFlight_stopsTheHandleAndThrowsCancellation() async {
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let handle = FakeQueryHandle()

    let task = Task {
      try await lifecycle.run(
        makeHandle: { handle },
        execute: { started in started.executed() }
      )
    }
    // Wait until the query is genuinely in flight before cancelling.
    while handle.executeCount == 0 { await Task.yield() }
    task.cancel()
    let result = await task.result

    #expect(throwsCancellation(result))
    #expect(handle.executeCount == 1)
    #expect(handle.stopCount == 1, "the in-flight query is stopped exactly once")
  }
}

/// True when the recorded outcome is a `CancellationError` failure.
func throwsCancellation<Success>(_ result: Result<Success, any Error>?) -> Bool {
  guard case .failure(let error) = result else { return false }
  return error is CancellationError
}
