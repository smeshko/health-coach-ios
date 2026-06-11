import CheckInRepository
import ComposableArchitecture
import DomainModels
import Foundation

/// The morning check-in (PRD §7.2) — the three self-report inputs with `kneePain` **constrained to
/// 0–10** so an out-of-range value can never be stored (DECISIONS #2: the clamping `kneePainChanged`
/// setter is the only mutation path for `kneePain`, so a 422 can't originate in the app). Loads today's
/// existing check-in via `CheckInRepository.current` and upserts via `save` (latest-wins same-day; the
/// repo owns the Europe/Sofia date key, 4.4).
///
/// An **internal** component of `TodayFeature` (ARCHITECTURE §4.5 / D5 "internal unless promoted") —
/// never its own target. A failed save is **non-fatal** (reverts to `.idle`, no error UI, no delegate —
/// the parent's chain is only re-entered by a *successful* save).
@Reducer
public struct CheckInComponent {
  /// The save lifecycle — `.saved` flips to `.idle` again on the next edit (a binding/toggle). 1-level
  /// nested (mirrors `ConnectComponent.Validation`).
  public enum SaveStatus: Equatable, Sendable { case idle, saving, saved }

  @ObservableState
  public struct State: Equatable {
    public var giSymptoms: Bool
    public var illness: Bool
    /// Always 0–10 — the only writer is the clamping `kneePainChanged` action (DECISIONS #2).
    public var kneePain: Int
    /// Today's loaded check-in (`nil` until `task` resolves, or when none is logged — a normal state).
    public var existing: DomainModels.CheckIn?
    public var saveStatus: SaveStatus
    /// The wall-clock instant of the **most recent save this session** — drives the footer's "Last saved
    /// <time>". `nil` until a save happens. Set from `\.date` on `saveResponse(.success)`. It is *not*
    /// seeded on load: the persisted `CheckIn` carries only a `startOfDay` day-key (no save instant), so
    /// rendering a clock time from it would show a wrong "12:00 AM"; the loaded case shows day-relative
    /// footer copy keyed off `existing` instead. Purely presentational — DECISIONS #2's clamp is untouched.
    public var lastSavedAt: Date?

    public init(
      giSymptoms: Bool = false,
      illness: Bool = false,
      kneePain: Int = 0,
      existing: DomainModels.CheckIn? = nil,
      saveStatus: SaveStatus = .idle,
      lastSavedAt: Date? = nil
    ) {
      self.giSymptoms = giSymptoms
      self.illness = illness
      self.kneePain = kneePain
      self.existing = existing
      self.saveStatus = saveStatus
      self.lastSavedAt = lastSavedAt
    }
  }

  /// The only thing the child tells its parent (`TodayFeature`): "the check-in was saved", so the parent
  /// re-enters the sync→brief chain ("Save & build today's brief" — a saved/edited check-in builds or
  /// regenerates the brief). 1-level nested.
  public enum Delegate: Equatable { case checkInSaved }

  public enum Action {
    /// View `task` — load today's existing check-in to seed the fields.
    case task
    case giSymptomsToggled(Bool)
    case illnessToggled(Bool)
    /// Clamped to `0...10` — the only mutation path for `kneePain` (DECISIONS #2).
    case kneePainChanged(Int)
    case saveTapped
    case delegate(Delegate)
    // Internal actions use TCA's `_`-prefix convention (not part of the public contract); the leading
    // underscore trips `identifier_name`, so scope a disable to these cases.
    // swiftlint:disable identifier_name
    /// The loaded check-in (or `nil`) routed back from the `task` effect to seed state.
    case _currentLoaded(DomainModels.CheckIn?)
    /// The `save` effect's result — success flips to `.saved` + emits the delegate; failure reverts.
    case saveResponse(Result<Void, any Error>)
    // swiftlint:enable identifier_name
  }

  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date

  public init() {}

  /// Today in the Europe/Sofia frame (the pinned `\.calendar`/`\.date`, CoachCore). The repo re-normalizes
  /// to start-of-day, but computing it here keeps the saved `CheckIn.date` deterministic + assertable.
  private var today: Date { calendar.startOfDay(for: date.now) }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let day = today
        return .run { [checkInRepository] send in
          let existing = await (try? checkInRepository.current(day)) ?? nil
          await send(._currentLoaded(existing))
        }

      case let ._currentLoaded(checkIn):
        guard let checkIn else { return .none }
        state.existing = checkIn
        state.giSymptoms = checkIn.giSymptoms
        state.illness = checkIn.illness
        state.kneePain = checkIn.kneePain
        // Don't seed `lastSavedAt` here — the persisted check-in has only a day-key, not a save instant,
        // so the footer would show "12:00 AM". The loaded case uses day-relative copy keyed off `existing`.
        return .none

      case let .giSymptomsToggled(isOn):
        state.giSymptoms = isOn
        return .none

      case let .illnessToggled(isOn):
        state.illness = isOn
        return .none

      case let .kneePainChanged(value):
        // The constrained setter — out-of-range is impossible by construction (DECISIONS #2).
        state.kneePain = min(10, max(0, value))
        return .none

      case .saveTapped:
        state.saveStatus = .saving
        let checkIn = DomainModels.CheckIn(
          date: today,
          giSymptoms: state.giSymptoms,
          kneePain: state.kneePain,
          illness: state.illness
        )
        return .run { [checkInRepository] send in
          do {
            try await checkInRepository.save(checkIn)
            await send(.saveResponse(.success(())))
          } catch {
            await send(.saveResponse(.failure(error)))
          }
        }

      case .saveResponse(.success):
        state.saveStatus = .saved
        state.lastSavedAt = date.now
        return .send(.delegate(.checkInSaved))

      case .saveResponse(.failure):
        // Non-fatal: revert quietly so the user can retry — no delegate, so the parent chain stays put.
        state.saveStatus = .idle
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
