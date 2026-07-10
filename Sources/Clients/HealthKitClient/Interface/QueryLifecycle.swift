import Foundation

/// A handle to a running query that can be stopped in place — the live conformance pairs an
/// `HKQuery` with its `HKHealthStore` (`stop = store.stop(query)`); tests use fakes. The interface
/// names only the capability so the lifecycle machinery stays host-testable with no HealthKit
/// import (that lives in `HealthKitClientLive`).
public protocol StoppableQuery: Sendable {
  func stop()
}

/// The type-erased face `BoundedReadCoordinator` needs from a `QueryLifecycle` regardless of its
/// handle/success types: cancel it (stopping any registered handle exactly once) and ask how many
/// live queries were actually stopped (the "stopped N in-flight queries" instrumentation count).
public protocol QueryCancelling: Sendable {
  /// Idempotent. Returns `true` only for the call that actually stopped a registered handle.
  @discardableResult
  func cancel() -> Bool
  /// Whether this lifecycle ever stopped a handle as timeout/cancellation CLEANUP. A normal
  /// one-shot stop on first delivery (`finishStoppingHandle`) does NOT flip this.
  var handleWasStopped: Bool { get }
  /// How many in-flight handles this lifecycle stopped as timeout/cancellation cleanup
  /// (TASK-004). Single-query lifecycles report the Boolean as 0/1 (the default below); a
  /// composite registry reports its exact stopped-child count so the coordinator's
  /// instrumentation never underreports N dynamic children as 1.
  var stoppedHandleCount: Int { get }
}

public extension QueryCancelling {
  var stoppedHandleCount: Int { handleWasStopped ? 1 : 0 }
}

/// A linearizable register/execute/cancel protocol for one callback-style query (Phase 18.2
/// validation round-2 #1 / round-3 #1 — a bare once-guard admits both a late-callback-claims-
/// success race and a cancel-before-registration orphan). Lock-synchronized state machine:
///
///     idle → registered(handle) → finished(result | cancelled)
///
/// Rules:
/// - `register` AFTER cancellation returns `.alreadyCancelled` — the handle is NEVER executed.
/// - `cancel` after registration records `CancellationError` FIRST, then stops the handle
///   EXACTLY once (`stop` does not guarantee the result callback fires, so the resume never
///   waits on it).
/// - a result callback after cancellation is dropped — it cannot claim success, not even empty.
/// - every path resumes the attached continuation exactly once.
public final class QueryLifecycle<Handle: StoppableQuery, Success: Sendable>: @unchecked Sendable {
  public typealias Resume = @Sendable (Result<Success, any Error>) -> Void

  public enum RegistrationOutcome: Sendable, Equatable {
    case proceed
    case alreadyCancelled
  }

  private enum Phase {
    case idle
    case registered(Handle)
    case finished
    case cancelled
  }

  private let lock = NSLock()
  private var phase: Phase = .idle
  private var sink: Resume?
  /// A terminal result decided before `attach` — delivered the moment the sink arrives.
  private var pendingResult: Result<Success, any Error>?
  private var stoppedHandle = false

  public init() {}

  public var handleWasStopped: Bool {
    lock.lock()
    defer { lock.unlock() }
    return stoppedHandle
  }

  /// Attaches the continuation's resume. If the lifecycle already reached a terminal state (e.g.
  /// cancelled before the continuation existed), the recorded result fires immediately.
  public func attach(_ resume: @escaping Resume) {
    lock.lock()
    let pending = pendingResult
    if pending == nil {
      sink = resume
    } else {
      pendingResult = nil
    }
    lock.unlock()
    if let pending { resume(pending) }
  }

  /// Registers the built handle. `.proceed` means the caller may execute it; `.alreadyCancelled`
  /// means cancellation won the race and the handle must never run (the continuation was already
  /// resumed with `CancellationError` by `cancel`).
  public func register(_ handle: Handle) -> RegistrationOutcome {
    lock.lock()
    defer { lock.unlock() }
    switch phase {
    case .idle:
      phase = .registered(handle)
      return .proceed
    case .registered, .finished, .cancelled:
      return .alreadyCancelled
    }
  }

  /// The query's result callback. Dropped entirely after cancellation or a prior result — a
  /// cancelled read can never complete as success, and nothing resumes twice.
  public func finish(_ value: Success) {
    lock.lock()
    switch phase {
    case .finished, .cancelled:
      lock.unlock()
    case .idle, .registered:
      resolveFinishedAndUnlock(value)
    }
  }

  /// One-shot delivery for a LONG-RUNNING, caller-stopped query (TASK-004 — the effort-
  /// relationship query keeps streaming updates, so `finish` alone would leave it running):
  /// delivers the first result exactly like `finish`, then stops the registered handle exactly
  /// once. This is a NORMAL completion stop, not timeout/cancellation cleanup — `handleWasStopped`
  /// stays `false` and it contributes 0 to `stoppedHandleCount`. Dropped entirely after
  /// cancellation (the cancel path already stopped the handle — never two stops) or a prior
  /// result, so repeated deliveries cannot stop twice or resume twice.
  public func finishStoppingHandle(_ value: Success) {
    lock.lock()
    switch phase {
    case .finished, .cancelled:
      lock.unlock()
    case .idle:
      resolveFinishedAndUnlock(value)
    case .registered(let handle):
      resolveFinishedAndUnlock(value)
      handle.stop()
    }
  }

  /// Cancels the lifecycle: records `CancellationError` (resuming the continuation) FIRST, then
  /// stops the registered handle exactly once. Idempotent; a no-op after a delivered result.
  @discardableResult
  public func cancel() -> Bool {
    lock.lock()
    switch phase {
    case .finished, .cancelled:
      lock.unlock()
      return false
    case .idle:
      resolveCancelledAndUnlock()
      return false
    case .registered(let handle):
      stoppedHandle = true
      resolveCancelledAndUnlock()
      handle.stop()
      return true
    }
  }

  /// Precondition: `lock` held. Flips to `.finished`, releases the lock, resumes with the value
  /// (or parks it for a late `attach`).
  private func resolveFinishedAndUnlock(_ value: Success) {
    phase = .finished
    let resume = sink
    sink = nil
    if resume == nil { pendingResult = .success(value) }
    lock.unlock()
    resume?(.success(value))
  }

  /// Precondition: `lock` held. Flips to `.cancelled`, releases the lock, resumes with
  /// `CancellationError` (or parks it for a late `attach`).
  private func resolveCancelledAndUnlock() {
    phase = .cancelled
    let resume = sink
    sink = nil
    if resume == nil { pendingResult = .failure(CancellationError()) }
    lock.unlock()
    resume?(.failure(CancellationError()))
  }
}

extension QueryLifecycle: QueryCancelling {}

public extension QueryLifecycle {
  /// Drives one whole query under task cancellation: attach the continuation, build + register
  /// the handle, and execute it — unless cancellation already won, in which case the handle is
  /// never executed. The query's result callback must call `finish`; cancellation stops the
  /// handle via the lifecycle rules above.
  func run(
    makeHandle: @escaping @Sendable () -> Handle,
    execute: @escaping @Sendable (Handle) -> Void
  ) async throws -> Success {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        attach { continuation.resume(with: $0) }
        let handle = makeHandle()
        if register(handle) == .proceed {
          execute(handle)
        }
      }
    } onCancel: {
      cancel()
    }
  }
}
