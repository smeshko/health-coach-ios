import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import LocalRepositories

/// The strength-test input feature (Epic 10.4) — two max-reps counts seeded from the last logged test,
/// a due callout, and a **Save** that writes a `StrengthTest` via `StrengthTestRepository.save`. The
/// weekly reminder (Phase 10.3) deep-links here; on a successful save it emits `Delegate.saved`, and the
/// parent (`MainTabs`) pops the screen and clears the due-dot.
///
/// The screen is week-agnostic: it sends today's numbers and `save` upserts by Europe/Sofia day
/// (latest-wins), so re-saving within an ISO week overwrites — matching the server's ISO-week keying.
///
/// **Load lifecycle (review #1):** the initial `current` read is an explicit `loadState` machine —
/// `loading → loaded | failed`. Save is gated on `.loaded` so a *failed* read can never become a `0/0`
/// upsert, the failed state offers a retry, and a late `.loaded` never clobbers edits the user has
/// already made (`userEdited`).
@Reducer
public struct StrengthTestFeature {
  /// Delegate actions the parent (`MainTabs`) listens for. `saved` fires once the test is written — the
  /// parent pops this screen and clears the You-tab + row due-dot.
  @CasePathable
  public enum Delegate: Equatable {
    case saved
  }

  /// The initial-read lifecycle. The screen is editable/saveable only in `.loaded`; `.failed` offers a
  /// retry. Nested directly on the reducer (not on `State`) to stay within the 1-level nesting lint.
  public enum LoadState: Equatable {
    case loading
    case loaded
    case failed
  }

  /// The save lifecycle. `saving` drives the primary button's busy state; `saved` is the transient
  /// terminal the view fires its `.success` haptic off (before the parent pops on `Delegate.saved`).
  /// `failed` is the user-visible save-failure state (Phase 20.2) — the view shows an error callout and
  /// fires an `.error` haptic; it is recoverable (the Save button stays live, and an edit clears it).
  public enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case failed
  }

  @ObservableState
  public struct State: Equatable {
    public var loadState: LoadState
    public var maxPushups: Int
    public var maxPullups: Int
    /// Whether a new test is due (no test logged this ISO week) — drives the callout. Derived from the
    /// loaded test's date via `isStrengthTestDue` (TASK-001).
    public var isDue: Bool
    public var saveState: SaveState
    /// Set once the user changes a stepper — guards against a late `.loaded` reseeding over their edits.
    public var userEdited: Bool

    public init(
      loadState: LoadState = .loading,
      maxPushups: Int = 0,
      maxPullups: Int = 0,
      isDue: Bool = true,
      saveState: SaveState = .idle,
      userEdited: Bool = false
    ) {
      self.loadState = loadState
      self.maxPushups = maxPushups
      self.maxPullups = maxPullups
      self.isDue = isDue
      self.saveState = saveState
      self.userEdited = userEdited
    }
  }

  public enum Action {
    case onAppear
    case retryTapped
    /// The latest test at-or-before today (`current(now)`), or `nil` if none logged. Only sent on a
    /// **successful** read — a thrown read sends `loadFailed` instead, so `nil` unambiguously means
    /// "no test logged" (not "the read failed").
    case loaded(DomainModels.StrengthTest?)
    case loadFailed
    case pushupsChanged(Int)
    case pullupsChanged(Int)
    case saveTapped
    case saveSucceeded
    case saveFailed
    case delegate(Delegate)
  }

  /// The sane count range. `−`/`+` clamp here authoritatively (the `NumericStepper` clamps defensively,
  /// but this reducer is the single writer of the stored value — DECISIONS #1 / the `SegmentStepper`
  /// convention).
  private static let countRange = 0 ... 300

  @Dependency(\.strengthTestRepository) var strengthTestRepository
  @Dependency(\.date) var date

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Auto-load once, only from the initial `.loading` state. A re-appear (already `.loaded`/`.failed`)
        // doesn't reload — the only writer of a `StrengthTest` is this screen, which pops on save, so the
        // loaded values can't go stale underneath it. (This also keeps a pre-seeded state stable, so the
        // appear hook never clobbers it.)
        guard state.loadState == .loading else { return .none }
        return loadEffect()

      case .retryTapped:
        state.loadState = .loading
        return loadEffect()

      case let .loaded(test):
        state.loadState = .loaded
        // Don't clobber edits the user made before a slow read returned (review #1). `isDue` is derived
        // state (not user-editable), so it always reflects the actual last test.
        if !state.userEdited {
          state.maxPushups = test?.maxPushups ?? 0
          state.maxPullups = test?.maxPullups ?? 0
        }
        state.isDue = isStrengthTestDue(lastTestDate: test?.date)
        return .none

      case .loadFailed:
        state.loadState = .failed
        return .none

      case let .pushupsChanged(value):
        // Ignore edits while a save is in flight — the save snapshots the counts, so a late edit would be
        // silently dropped on the pop (review #2). The view also shows the controls as busy.
        guard state.saveState != .saving else { return .none }
        clearSaveFailure(&state)
        state.userEdited = true
        state.maxPushups = value.clamped(to: Self.countRange)
        return .none

      case let .pullupsChanged(value):
        guard state.saveState != .saving else { return .none }
        clearSaveFailure(&state)
        state.userEdited = true
        state.maxPullups = value.clamped(to: Self.countRange)
        return .none

      case .saveTapped:
        // Save only from a successful load (so a failed read can't become a 0/0 upsert) and not re-entrant.
        guard state.loadState == .loaded, state.saveState != .saving else { return .none }
        state.saveState = .saving
        let test = DomainModels.StrengthTest(
          date: date.now, maxPushups: state.maxPushups, maxPullups: state.maxPullups
        )
        return .run { [strengthTestRepository] send in
          do {
            try await strengthTestRepository.save(test)
            await send(.saveSucceeded)
          } catch {
            await send(.saveFailed)
          }
        }

      case .saveSucceeded:
        // Flip `saveState` to `.saved` FIRST so the view's `.success` haptic (keyed on this change) fires
        // even though the parent pops the screen on `Delegate.saved` in the same step (validation #5).
        state.saveState = .saved
        return .send(.delegate(.saved))

      case .saveFailed:
        // Surface the failure (Phase 20.2): `.failed` renders an error callout + `.error` haptic instead
        // of silently reverting to `.idle`. Recoverable — `saveTapped` still fires from `.failed`, and
        // an edit clears it back to `.idle`.
        state.saveState = .failed
        return .none

      case .delegate:
        return .none
      }
    }
  }

  /// Clears a surfaced save failure once the user edits — the error callout describes the *previous*
  /// attempt, so it must not linger over fresh numbers (Phase 20.2).
  private func clearSaveFailure(_ state: inout State) {
    if state.saveState == .failed { state.saveState = .idle }
  }

  /// Reads the latest test → `loaded`, or `loadFailed` on a thrown read. Catching the error (rather than
  /// `try?`) keeps a failed read distinct from a real `nil` "no test logged", so a failure can never
  /// become a saveable `0/0` (review #1).
  private func loadEffect() -> Effect<Action> {
    .run { [strengthTestRepository, now = date.now] send in
      do {
        await send(.loaded(try await strengthTestRepository.current(now)))
      } catch {
        await send(.loadFailed)
      }
    }
  }
}

private extension Int {
  func clamped(to range: ClosedRange<Int>) -> Int {
    Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
  }
}
