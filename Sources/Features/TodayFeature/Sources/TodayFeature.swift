import BriefRepository
import CheckInRepository
import ComposableArchitecture
import DomainModels
import Foundation
import LogClient
import SyncRepository

/// The Today tab's root reducer (ARCHITECTURE §4.5, PRD §6/§8.1) — the hero "daily brief" screen. It owns
/// the universal `BriefViewState` lifecycle (the single source of truth, DECISIONS #1) and the morning
/// orchestration effect (check-in → sync → daily brief, **sync strictly before the brief**, D15/§11). The
/// 8.2/8.3/8.4 sub-sections plug into stable seams under `ready` without restructuring this parent; the
/// lifecycle case set is fixed now (later phases add *content*, not new cases).
///
/// **Feature dependency rule (§3):** imports only the repo **interfaces** (`BriefRepository`/
/// `SyncRepository`/`CheckInRepository`, via `BriefViewState` + `@Dependency` later) + `DesignSystem` +
/// `DomainModels` + `CoachCore` + `ComposableArchitecture` — never a `*Live`, data-source client,
/// `WireModels`, GRDB, or HealthKit.
@Reducer
public struct TodayFeature {
  @ObservableState
  public struct State: Equatable {
    /// The screen lifecycle — the one source of truth (DECISIONS #1). No sibling `isLoading`/`error`
    /// bools; the enum is exhaustive.
    public var briefState: BriefViewState
    /// The morning check-in child (PRD §7.2). Always present; rendered in the `ready` branch.
    public var checkIn: CheckInComponent.State
    /// The 2026-06-10 shell's Exercise | Nutrition segmented toggle (local UI state). 8.2/8.3 render
    /// under `.exercise`, 8.4 under `.nutrition`.
    public var selectedSection: TodaySection
    /// Set by the orchestration on a successful `sync()` — drives the header's relative "Synced 2m ago"
    /// pill via the CoachCore date dependency.
    public var lastSyncedAt: Date?
    /// `true` once the check-in is saved after a brief is shown → the view offers Refresh so a corrected
    /// check-in can regenerate the brief (PRD §8.6). Cleared when a fresh brief lands.
    public var offerRefresh: Bool

    public init(
      briefState: BriefViewState = .idle,
      checkIn: CheckInComponent.State = CheckInComponent.State(),
      selectedSection: TodaySection = .exercise,
      lastSyncedAt: Date? = nil,
      offerRefresh: Bool = false
    ) {
      self.briefState = briefState
      self.checkIn = checkIn
      self.selectedSection = selectedSection
      self.lastSyncedAt = lastSyncedAt
      self.offerRefresh = offerRefresh
    }
  }

  public enum Action {
    /// Sent by the host on app-open — drives the morning orchestration.
    case onAppOpen
    /// The Refresh affordance — a debounced re-run of the orchestration with `refresh: true` (TASK-004).
    case refreshTapped
    /// Retry from a `.syncFailed`/`.error` terminal — re-runs the full sync-first chain.
    case retryTapped
    /// The segmented toggle — pure UI, flips `selectedSection`.
    case sectionSelected(TodaySection)
    /// The morning check-in child's actions.
    case checkIn(CheckInComponent.Action)
    // Internal transition actions drive the orchestration's `BriefViewState` mutations through the
    // reducer. The leading underscore (TCA convention) trips `identifier_name`, so scope a disable.
    // swiftlint:disable identifier_name
    /// Fired once the Refresh debounce window elapses — runs the shared chain with `refresh: true`.
    case _runOrchestration(refresh: Bool)
    case _syncStarted
    case _syncFailed(SyncError)
    case _generating
    case _briefResolved(DomainModels.DailyBrief, Freshness)
    case _briefFailed(BriefError)
    // swiftlint:enable identifier_name
  }

  /// Cancellation namespace. `.orchestration` owns the chained sync→brief `.run`; a new trigger
  /// (`onAppOpen`/`retryTapped`, or a fired Refresh) cancels it in-flight so a stale brief can't land
  /// after a newer request. `.refreshDebounce` owns the Refresh debounce window (so rapid `refreshTapped`
  /// collapse the pending window) — kept distinct so an `onAppOpen`-started run is still cancellable.
  public enum CancelID: Hashable, Sendable { case orchestration, refreshDebounce }

  /// The Refresh debounce window (PRD §8.6 — collapse refresh-spam re-rolls). A named constant so the
  /// `TestClock` test advances exactly past it (no magic number duplicated between source and test).
  static let refreshDebounceWindow: Duration = .milliseconds(300)

  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.syncRepository) var syncRepository
  @Dependency(\.briefRepository) var briefRepository
  @Dependency(\.continuousClock) var clock
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date
  @Dependency(\.log) var log

  public init() {}

  /// Today in the Europe/Sofia frame (the pinned `\.calendar`/`\.date`, CoachCore) — the key the
  /// orchestration reads the check-in for.
  private var today: Date { calendar.startOfDay(for: date.now) }

  public var body: some ReducerOf<Self> {
    Scope(state: \.checkIn, action: \.checkIn) {
      CheckInComponent()
    }
    Reduce { state, action in
      switch action {
      case let .sectionSelected(section):
        state.selectedSection = section
        return .none

      case .onAppOpen:
        // The morning orchestration (sync strictly before the brief) — the open path, `refresh: false`.
        log.info("App-open — starting morning orchestration", category: .lifecycle)
        return orchestrationEffect(refresh: false)

      case .retryTapped:
        // Retry from a terminal — re-runs the same sync-first chain (open path, `refresh: false`).
        return orchestrationEffect(refresh: false)

      case .refreshTapped:
        // Debounce over the clock to collapse refresh-spam (PRD §8.6), then run the shared chain with
        // `refresh: true`. The debounce sleep is on `.refreshDebounce` (so rapid taps collapse the
        // pending window); the orchestration `.run` it fires is on `.orchestration` (so a new trigger
        // cancels the in-flight *run*).
        return .run { [clock] send in
          try await clock.sleep(for: Self.refreshDebounceWindow)
          await send(._runOrchestration(refresh: true))
        }
        .cancellable(id: CancelID.refreshDebounce, cancelInFlight: true)

      case let ._runOrchestration(refresh):
        return orchestrationEffect(refresh: refresh)

      case ._syncStarted:
        state.briefState = .syncing
        return .none

      case let ._syncFailed(error):
        // Block-and-retry: the brief was never requested (D23/§11).
        state.briefState = .syncFailed(error)
        return .none

      case ._generating:
        // Reaching `.generating` means `sync()` succeeded → record the sync time (the header pill's
        // source) and move to the brief request.
        state.lastSyncedAt = date.now
        state.briefState = .generating
        return .none

      case let ._briefResolved(brief, freshness):
        state.offerRefresh = false
        state.briefState = .ready(brief, freshness)
        return .none

      case let ._briefFailed(error):
        state.briefState = .error(error)
        return .none

      case .checkIn(.delegate(.checkInSaved)):
        // The user edited + saved the check-in → offer Refresh so a corrected check-in can regenerate the
        // brief (PRD §8.6). The `refreshTapped` re-run is wired in TASK-004.
        state.offerRefresh = true
        return .none

      case .checkIn:
        return .none
      }
    }
  }

  /// The morning orchestration as **one** chained, cancellable effect (D15/§11): seed the check-in (never
  /// hard-blocks) → `sync()` (must precede the brief; on failure set `.syncFailed` and **STOP** — the
  /// brief closure is never reached, D23/§11) → `dailyBrief(refresh:)`. A new trigger cancels the
  /// in-flight run (`cancelInFlight: true`, TASK-004's debounce + cancellation coverage) so a stale brief
  /// can't land after a newer request. Each `await` carries the typed catch **plus a catch-all**: 4.3 says
  /// a 401 propagates from `sync()` as **not** a `SyncError` (session-stream-handled, §13/D13), so a
  /// typed-only catch would let it escape and wedge `.syncing`/`.generating` with no Retry — the catch-all
  /// maps any unexpected throw to a terminal retryable state instead.
  private func orchestrationEffect(refresh: Bool) -> Effect<Action> {
    let day = today
    return .run { [checkInRepository, syncRepository, briefRepository] send in
      // 1. Seed/prompt the check-in — a nil/throw never blocks the chain (DECISIONS #3).
      _ = try? await checkInRepository.current(day)

      // 2. Sync MUST precede the brief.
      await send(._syncStarted)
      do {
        _ = try await syncRepository.sync()
      } catch let error as SyncError {
        await send(._syncFailed(error))
        return
      } catch {
        await send(._syncFailed(.transient))
        return
      }

      // 3. Generate the brief (the open path uses `refresh: false`; the Refresh path passes `true`).
      await send(._generating)
      do {
        let brief = try await briefRepository.dailyBrief(refresh)
        await send(._briefResolved(brief, brief.cached ? .cached : .fresh))
      } catch let error as BriefError {
        await send(._briefFailed(error))
      } catch {
        await send(._briefFailed(.transientGenerationFailed))
      }
      // new ISO week → weeklyBrief() — Epic 09 (out of scope here; a seam only).
    }
    .cancellable(id: CancelID.orchestration, cancelInFlight: true)
  }
}

/// The Exercise | Nutrition segmented toggle's selection (the 2026-06-10 shell). Top-level (not nested in
/// `TodayFeature`) to stay within the 1-level type-nesting lint rule.
public enum TodaySection: Equatable, Sendable { case exercise, nutrition }
