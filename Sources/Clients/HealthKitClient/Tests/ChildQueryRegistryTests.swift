import Foundation
import Testing

@testable import HealthKitClient

/// Pins the composite child-query registry (TASK-004 / D2): lifecycles spawned dynamically —
/// after the coordinator's fixed array was built — are owned by one `QueryCancelling` that sits
/// in that array upfront. Cancellation reaches every child exactly once, late-added children
/// have no escape window, post-cancellation deliveries cannot contribute, and
/// `stoppedHandleCount` reports cleanup stops exactly (never normal one-shot completions).
struct ChildQueryRegistryTests {
  private struct Child {
    let handle = FakeQueryHandle()
    let lifecycle = QueryLifecycle<FakeQueryHandle, Int>()
    let recorder = ResumeRecorder<Int>()

    /// Attach + register, i.e. the child query is genuinely in flight.
    func start() {
      lifecycle.attach { recorder.record($0) }
      _ = lifecycle.register(handle)
    }
  }

  @Test func test_cancel_stopsEveryRegisteredChildExactlyOnce() {
    let registry = ChildQueryRegistry()
    let children = [Child(), Child(), Child()]
    for child in children {
      child.start()
      registry.add(child.lifecycle)
    }

    #expect(registry.cancel() == true, "at least one live child was stopped")

    for child in children {
      #expect(child.handle.stopCount == 1, "every child stopped exactly once")
      #expect(throwsCancellation(child.recorder.results.first))
    }
    #expect(registry.stoppedHandleCount == 3, "the exact child count — no Boolean underreporting")
    #expect(registry.handleWasStopped == true)
  }

  @Test func test_secondCancel_isANoOp_andNeverDoubleStops() {
    let registry = ChildQueryRegistry()
    let child = Child()
    child.start()
    registry.add(child.lifecycle)

    #expect(registry.cancel() == true)
    #expect(registry.cancel() == false, "a second cancel stops nothing new")
    #expect(child.handle.stopCount == 1)
    #expect(registry.stoppedHandleCount == 1)
  }

  @Test func test_childAddedAfterCancel_isStoppedImmediately() {
    let registry = ChildQueryRegistry()
    registry.cancel()

    let child = Child()
    child.start()
    registry.add(child.lifecycle)

    #expect(child.handle.stopCount == 1, "no escape window for late-added in-flight children")
    #expect(throwsCancellation(child.recorder.results.first))
    #expect(registry.stoppedHandleCount == 1)
  }

  @Test func test_childAddedAfterCancel_beforeRegistration_neverExecutes() {
    let registry = ChildQueryRegistry()
    registry.cancel()

    let child = Child()
    registry.add(child.lifecycle)
    child.lifecycle.attach { child.recorder.record($0) }
    #expect(
      child.lifecycle.register(child.handle) == .alreadyCancelled,
      "registration after the registry's cancel is refused by the child's own rules"
    )
    #expect(child.handle.stopCount == 0, "a never-executed handle needs no stop")
    #expect(throwsCancellation(child.recorder.results.first))
  }

  @Test func test_postCancellationDelivery_cannotContribute() {
    let registry = ChildQueryRegistry()
    let child = Child()
    child.start()
    registry.add(child.lifecycle)

    registry.cancel()
    child.lifecycle.finish(7)

    #expect(child.recorder.results.count == 1, "the late delivery cannot resume a second time")
    #expect(throwsCancellation(child.recorder.results.first), "cancellation is kept, not success")
  }

  @Test func test_stoppedHandleCount_excludesNormallyCompletedChildren() {
    let registry = ChildQueryRegistry()
    let completed = Child()
    let wedged = Child()
    completed.start()
    wedged.start()
    registry.add(completed.lifecycle)
    registry.add(wedged.lifecycle)

    completed.lifecycle.finishStoppingHandle(42)
    registry.cancel()

    #expect(completed.handle.stopCount == 1, "one-shot completion stopped the long-running query")
    #expect(wedged.handle.stopCount == 1, "cleanup stopped the still-in-flight query")
    #expect(registry.stoppedHandleCount == 1, "only the cleanup stop is counted")
  }
}
