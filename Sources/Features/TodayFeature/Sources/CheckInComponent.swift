import ComposableArchitecture
import DomainModels
import Foundation
import LocalRepositories

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
  @ObservableState
  public struct State: Equatable {
    public var giSymptoms: Bool
    public var illness: Bool
    /// Always 0–10 — the only writer is the clamping `kneePainChanged` action (DECISIONS #2).
    public var kneePain: Int
    /// Today's loaded check-in (`nil` until `task` resolves, or when none is logged — a normal state).
    public var existing: DomainModels.CheckIn?
    /// True while a save effect is in flight (drives the spinner + the `saveTapped` re-entry guard).
    public var isSaving: Bool
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
      isSaving: Bool = false,
      lastSavedAt: Date? = nil
    ) {
      self.giSymptoms = giSymptoms
      self.illness = illness
      self.kneePain = kneePain
      self.existing = existing
      self.isSaving = isSaving
      self.lastSavedAt = lastSavedAt
    }
  }

  /// The only thing the child tells its parent (`TodayFeature`): "the check-in was saved", so the parent
  /// re-enters the sync→brief chain ("Save & build today's brief" — a saved/edited check-in builds or
  /// regenerates the brief). 1-level nested.
  public enum Delegate: Equatable { case checkInSaved }

  /// The child's in-flight effects, cancellable from the parent's rollover branch (review #1.1): the
  /// reset is a pure state mutation, so without cancellation a pre-midnight load/save suspended across
  /// midnight would deliver into the freshly reset state — re-seeding yesterday's answers, stamping
  /// `lastSavedAt` with the new day's clock, or firing a stale `checkInSaved` delegate for a check-in
  /// persisted under yesterday's day key.
  enum CancelID { case load, save }

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
    /// The `save` effect's result — success clears `isSaving` + emits the delegate; failure reverts.
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

  /// The one day guard for the "Saved earlier today" footer (defense in depth on top of the rollover
  /// reset — DECISIONS D3): true only when `existing` is dated the same Sofia day as `now`, so a
  /// delayed/missed reset or a child-reload window can never present yesterday's save as today's. Pure
  /// (no dependency reads) so the view can call it deterministically and tests can pin the exact
  /// Sofia-midnight boundary. Uses `isDate(_:inSameDayAs:)` — not `==` — because although the repo
  /// normalizes `CheckIn.date` to `startOfDay` on save, an un-normalized value from any future source
  /// must still compare correctly.
  public static func isSameSofiaDay(_ existing: DomainModels.CheckIn?, now: Date, calendar: Calendar) -> Bool {
    guard let existing else { return false }
    return calendar.isDate(existing.date, inSameDayAs: now)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let day = today
        return .run { [checkInRepository] send in
          let existing = await (try? checkInRepository.current(day)) ?? nil
          await send(._currentLoaded(existing))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)

      case let ._currentLoaded(checkIn):
        guard let checkIn else { return .none }
        // Defense in depth on top of the rollover cancellation (review #1.1): a load that raced the
        // cancel can still deliver yesterday's record after midnight — never seed a stale day.
        guard Self.isSameSofiaDay(checkIn, now: date.now, calendar: calendar) else { return .none }
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
        // Re-entry guard (D7): a second tap while saving would fire a second save → a second
        // `checkInSaved` delegate → a duplicate orchestration. The button is `.disabled(isSaving)`,
        // so this is UI-invisible defence.
        guard !state.isSaving else { return .none }
        state.isSaving = true
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
        .cancellable(id: CancelID.save)

      case .saveResponse(.success):
        state.isSaving = false
        state.lastSavedAt = date.now
        return .send(.delegate(.checkInSaved))

      case .saveResponse(.failure):
        // Non-fatal: revert quietly so the user can retry — no delegate, so the parent chain stays put.
        state.isSaving = false
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
