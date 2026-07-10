import Foundation

/// A composite `QueryCancelling` owning query lifecycles that are spawned DYNAMICALLY — after the
/// coordinator's fixed lifecycle array was built (TASK-004: one effort-relationship query per
/// workout, created only once the workouts query has delivered its samples). The registry itself
/// is placed in `BoundedReadCoordinator`'s array UPFRONT, so the coordinator's fixed-array shape
/// is unchanged; children register here as they are created.
///
/// Contract (pinned by `ChildQueryRegistryTests` / `BoundedReadCoordinatorDynamicChildTests`):
/// - `cancel()` forwards to every child; each child stops its registered handle exactly once
///   (the child's own `QueryLifecycle` idempotence).
/// - a child added AFTER the registry was cancelled is cancelled immediately — no escape window.
/// - `stoppedHandleCount` sums the children's counts, so the coordinator's "stopped N in-flight
///   queries" instrumentation reports every dynamic child exactly — and ONLY cleanup stops: a
///   child that completed normally via `finishStoppingHandle` contributes 0.
public final class ChildQueryRegistry: QueryCancelling, @unchecked Sendable {
  private let lock = NSLock()
  private var children: [any QueryCancelling] = []
  private var cancelled = false

  public init() {}

  /// Registers a child lifecycle. If the registry was already cancelled, the child is cancelled
  /// on the spot (a not-yet-registered child then refuses its handle via the lifecycle's own
  /// cancel-before-registration rule).
  public func add(_ child: any QueryCancelling) {
    lock.lock()
    children.append(child)
    let alreadyCancelled = cancelled
    lock.unlock()
    if alreadyCancelled { child.cancel() }
  }

  /// Cancels every child (idempotent per child — the ones an earlier sweep or task-cancellation
  /// path already reached are no-ops). Returns `true` only when this call actually stopped at
  /// least one registered handle.
  @discardableResult
  public func cancel() -> Bool {
    lock.lock()
    cancelled = true
    let snapshot = children
    lock.unlock()
    var stoppedAny = false
    for child in snapshot where child.cancel() {
      stoppedAny = true
    }
    return stoppedAny
  }

  /// Whether any child was stopped as cleanup (derived from the exact count).
  public var handleWasStopped: Bool {
    stoppedHandleCount > 0
  }

  /// The exact number of children stopped by timeout/cancellation cleanup — never the Boolean
  /// underreport, never a normally-completed one-shot child.
  public var stoppedHandleCount: Int {
    lock.lock()
    let snapshot = children
    lock.unlock()
    return snapshot.reduce(0) { $0 + $1.stoppedHandleCount }
  }
}
