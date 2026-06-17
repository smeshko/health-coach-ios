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
@Reducer
public struct StrengthTestFeature {
  /// Delegate actions the parent (`MainTabs`) listens for. `saved` fires once the test is written — the
  /// parent pops this screen and clears the You-tab + row due-dot.
  @CasePathable
  public enum Delegate: Equatable {
    case saved
  }

  /// The save lifecycle. `saving` drives the primary button's busy state; `saved` is the transient
  /// terminal the view fires its `.success` haptic off (before the parent pops on `Delegate.saved`).
  /// Nested directly on the reducer (not on `State`) to stay within the 1-level nesting lint.
  public enum SaveState: Equatable {
    case idle
    case saving
    case saved
  }

  @ObservableState
  public struct State: Equatable {
    public var maxPushups: Int
    public var maxPullups: Int
    /// Whether a new test is due (no test logged this ISO week) — drives the callout. Derived from the
    /// seeded test's date on `onAppear` via `isStrengthTestDue` (TASK-001).
    public var isDue: Bool
    public var saveState: SaveState

    public init(maxPushups: Int = 0, maxPullups: Int = 0, isDue: Bool = true, saveState: SaveState = .idle) {
      self.maxPushups = maxPushups
      self.maxPullups = maxPullups
      self.isDue = isDue
      self.saveState = saveState
    }
  }

  public enum Action {
    case onAppear
    /// The latest test at-or-before today (`current(now)`), or `nil` if none logged.
    case loaded(DomainModels.StrengthTest?)
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
        return .run { [strengthTestRepository, now = date.now] send in
          let test = try? await strengthTestRepository.current(now)
          await send(.loaded(test))
        }

      case let .loaded(test):
        // Seed from the last logged test (leave 0/0 if none), then derive the due state from its date —
        // `isStrengthTestDue` reads `\.calendar`/`\.date` itself, so it needs no explicit args.
        if let test {
          state.maxPushups = test.maxPushups
          state.maxPullups = test.maxPullups
        }
        state.isDue = isStrengthTestDue(lastTestDate: test?.date)
        return .none

      case let .pushupsChanged(value):
        state.maxPushups = value.clamped(to: Self.countRange)
        return .none

      case let .pullupsChanged(value):
        state.maxPullups = value.clamped(to: Self.countRange)
        return .none

      case .saveTapped:
        guard state.saveState != .saving else { return .none }
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
        // A rare on-device save failure → back to idle so the user can retry.
        state.saveState = .idle
        return .none

      case .delegate:
        return .none
      }
    }
  }
}

private extension Int {
  func clamped(to range: ClosedRange<Int>) -> Int {
    Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
  }
}
