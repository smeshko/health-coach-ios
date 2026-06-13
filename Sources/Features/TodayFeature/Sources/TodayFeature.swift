import BriefRepository
import ComposableArchitecture
import DomainModels
import Foundation
import LocalRepositories
import LogClient
import ProfileRepository
import SyncRepository

/// The Today tab's root reducer (ARCHITECTURE §4.5, PRD §6/§8.1) — the hero "daily brief" screen. It owns
/// the universal `BriefViewState` lifecycle (the single source of truth, DECISIONS #1) and the morning
/// orchestration effect (check-in → sync → daily brief, **sync strictly before the brief**, D15/§11).
/// The check-in **gates** the chain (the 2026-06-10 design iteration, superseding PRD §7.2's
/// never-blocks rule): no check-in saved today → `.checkInRequired` (the check-in screen, no sync);
/// "Save & build today's brief" re-enters the chain with `refresh: true`. The 8.2/8.3/8.4 sub-sections
/// plug into stable seams under `ready` without restructuring this parent.
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
    /// The morning check-in child (PRD §7.2). Always present; rendered standalone in `.checkInRequired`
    /// (the gate) and editable again under `ready`.
    public var checkIn: CheckInComponent.State
    /// The readiness sub-component (Phase 8.3) — hydrated from `brief.readiness` when a brief resolves,
    /// `nil` otherwise. Held in parent state (not derived per-render) so the "why" expand/collapse toggle
    /// persists across re-renders (DECISIONS #1); scoped via `ifLet`. (The `SafetyRestComponent` is
    /// render-only — no in-screen interaction — so it is constructed inline in the view, not held here.)
    public var readiness: ReadinessComponent.State?
    /// The promoted daily-session child (Phase 8.4) — the `SessionCard` + inline swap. Hydrated from the
    /// resolved brief **only on an untripped day** (`!safetyGate.triggered`, the `.normal` mode); `nil`
    /// otherwise (forced-REST renders the inline `SafetyRestView` instead, no swap/skip). Held in parent
    /// state (not derived per-render) so the swap selection + expansion persist across re-renders
    /// (DECISIONS #1); scoped via `ifLet`.
    public var session: SessionFeature.State?
    /// The five-zone bpm map (`ProfileRepository.zones()`), fetched by the orchestration and handed to the
    /// session child so a *swapped* alternative's `zoneTarget` resolves its bpm range (DECISIONS #4).
    /// `nil` until the fetch lands (or if it fails — a non-fatal degrade: the chip just doesn't render).
    public var zones: Zones?
    /// The 2026-06-10 shell's Exercise | Nutrition segmented toggle (local UI state). 8.2/8.3 render
    /// under `.exercise`, 8.4 under `.nutrition`.
    public var selectedSection: TodaySection
    /// Set by the orchestration on a successful `sync()` — drives the header's relative "Synced 2m ago"
    /// pill via the CoachCore date dependency.
    public var lastSyncedAt: Date?

    public init(
      briefState: BriefViewState = .idle,
      checkIn: CheckInComponent.State = CheckInComponent.State(),
      readiness: ReadinessComponent.State? = nil,
      session: SessionFeature.State? = nil,
      zones: Zones? = nil,
      selectedSection: TodaySection = .exercise,
      lastSyncedAt: Date? = nil
    ) {
      self.briefState = briefState
      self.checkIn = checkIn
      self.readiness = readiness
      self.session = session
      self.zones = zones
      self.selectedSection = selectedSection
      self.lastSyncedAt = lastSyncedAt
    }
  }

  public enum Action {
    /// Sent by the host on app-open — drives the morning orchestration.
    case onAppOpen
    /// Retry from a `.syncFailed`/`.error` terminal — re-runs the full sync-first chain.
    case retryTapped
    /// The segmented toggle — pure UI, flips `selectedSection`.
    case sectionSelected(TodaySection)
    /// The morning check-in child's actions.
    case checkIn(CheckInComponent.Action)
    /// The readiness child's actions (the "why" toggle) — scoped via `ifLet` while a brief is loaded.
    case readiness(ReadinessComponent.Action)
    /// The daily-session child's actions (inline swap + the skip-requested delegate) — scoped via `ifLet`
    /// on an untripped day.
    case session(SessionFeature.Action)
    // Internal transition actions drive the orchestration's `BriefViewState` mutations through the
    // reducer. The leading underscore (TCA convention) trips `identifier_name`, so scope a disable.
    // swiftlint:disable identifier_name
    /// No check-in saved today — the chain stops at the check-in screen (the gate).
    case _checkInRequired
    case _syncStarted
    case _syncFailed(SyncError)
    case _generating
    /// The resolved brief + its freshness + the (non-fatal) HR zones, in **one** payload — the reducer
    /// hydrates `state.zones` from it FIRST, then the session child reads `state.zones` while hydrating, so
    /// there is no cross-action ordering to get wrong (DECISIONS #4 / Phase 11.4 D2). `zones == nil` is a
    /// silent degrade (no zone chip).
    case _briefResolved(DomainModels.DailyBrief, Freshness, Zones?)
    case _briefFailed(BriefError)
    // swiftlint:enable identifier_name
  }

  /// Cancellation namespace. `.orchestration` owns the chained sync→brief `.run`; a new trigger
  /// (`onAppOpen`/`retryTapped`, or a check-in save) cancels it in-flight so a stale brief can't land
  /// after a newer request.
  public enum CancelID: Hashable, Sendable { case orchestration }

  /// The minimum time each loading phase (`.syncing`, `.generating`) stays on screen. The mock backend
  /// (and a same-day cache hit) resolves within a frame, which made "Save & build today's brief" look
  /// like a no-op — the designed `2 ·`/`3 · Loading` screens never appeared. The dwell runs **concurrent**
  /// with the work (`async let`), so a slow real backend isn't slowed further; failures skip it (errors
  /// surface immediately). A named constant so tests advance a `TestClock` exactly past it.
  static let loadingPhaseMinDuration: Duration = .seconds(1)

  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.syncRepository) var syncRepository
  @Dependency(\.briefRepository) var briefRepository
  @Dependency(\.profileRepository) var profileRepository
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

      case ._checkInRequired:
        state.briefState = .checkInRequired
        return .none

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

      case let ._briefResolved(brief, freshness, zones):
        state.briefState = .ready(brief, freshness)
        // Hydrate `state.zones` FIRST, from this single payload, so the session child below reads it while
        // hydrating (DECISIONS #4 / Phase 11.4 D2 — one resolved payload, no cross-action ordering). A
        // `nil` fetch degrades silently (no zone chip).
        state.zones = zones
        // Hydrate the readiness child from the resolved brief (Phase 8.3) so the gauge + its persisted
        // "why" toggle render under `ready`. A fresh brief resets the toggle to collapsed.
        state.readiness = ReadinessComponent.State(readiness: brief.readiness)
        // Hydrate the daily-session child (Phase 8.4) — **only on an untripped day** (`.normal` mode);
        // a tripped gate renders the inline `SafetyRestView` instead, so leave `session` nil there. The
        // `.session` narrative slice is pre-filtered for the in-card slot (DECISIONS #3); a fresh brief
        // re-seeds the child, resetting any swap selection/expansion.
        state.session = brief.safetyGate.triggered
          ? nil
          : SessionFeature.State(
            session: brief.session,
            alternatives: brief.alternatives,
            skipOk: brief.skipOk,
            narrative: brief.narrative.filter { $0.type == .session },
            zones: state.zones
          )
        return .none

      case let ._briefFailed(error):
        state.briefState = .error(error)
        return .none

      case .checkIn(.delegate(.checkInSaved)):
        // "Save & build today's brief" — the saved check-in unlocks the gate, so re-enter the chain with
        // `refresh: true` (a corrected check-in regenerates the brief rather than serving the cache).
        log.info("Check-in saved — building today's brief", category: .lifecycle)
        return orchestrationEffect(refresh: true)

      case .checkIn:
        return .none

      case .readiness:
        // The "why" toggle is handled by the scoped child reducer (below).
        return .none

      case .session(.delegate(.skipRequested)):
        // The athlete asked to skip today's session. Permission, not dismiss (PRD §7.4.3) — the card
        // stays; the parent just records intent. Analytics/ack land later; for now an observability line.
        log.info("Athlete requested to skip today's session", category: .lifecycle)
        return .none

      case .session:
        // The inline swap (expand/collapse, select/revert) is handled by the scoped child reducer (below).
        return .none
      }
    }
    .ifLet(\.readiness, action: \.readiness) {
      ReadinessComponent()
    }
    .ifLet(\.session, action: \.session) {
      SessionFeature()
    }
  }

  /// The morning orchestration as **one** chained, cancellable effect (D15/§11): the check-in **gate**
  /// (no check-in saved today → `.checkInRequired`, **STOP** — no sync; "Save & build today's brief"
  /// re-enters) → `sync()` (must precede the brief; on failure set `.syncFailed` and **STOP** — the
  /// brief closure is never reached, D23/§11) → `dailyBrief(refresh:)`. A new trigger cancels the
  /// in-flight run (`cancelInFlight: true`) so a stale brief can't land after a newer request. Each
  /// `await` carries the typed catch **plus a catch-all**: 4.3 says a 401 propagates from `sync()` as
  /// **not** a `SyncError` (session-stream-handled, §13/D13), so a typed-only catch would let it escape
  /// and wedge `.syncing`/`.generating` with no Retry — the catch-all maps any unexpected throw to a
  /// terminal retryable state instead.
  private func orchestrationEffect(refresh: Bool) -> Effect<Action> {
    let day = today
    return .run { [checkInRepository, syncRepository, briefRepository, profileRepository, clock] send in
      // 1. The check-in gates the chain (2026-06-10 design): nothing saved today → show the check-in
      //    screen and stop. A read error degrades to the same gate (the user saves their way through).
      let existing = await (try? checkInRepository.current(day)) ?? nil
      guard existing != nil else {
        await send(._checkInRequired)
        return
      }

      // 2. Sync MUST precede the brief. The min-dwell sleep runs concurrent with the work and is only
      //    awaited on success — a failure surfaces immediately.
      await send(._syncStarted)
      do {
        async let dwell: Void = clock.sleep(for: Self.loadingPhaseMinDuration)
        _ = try await syncRepository.sync()
        try? await dwell
      } catch let error as SyncError {
        await send(._syncFailed(error))
        return
      } catch {
        await send(._syncFailed(.transient))
        return
      }

      // 3. Generate the brief (the open path uses `refresh: false`; the save path passes `true`). The HR
      //    zones are fetched **concurrently** (`async let`) so the swap child can resolve a swapped
      //    alternative's bpm range (DECISIONS #4) without adding latency; the fetch is non-fatal
      //    (`try?` → `nil`) so a zones failure never blocks the brief. Both fetches are awaited and ride
      //    on **one** `._briefResolved(brief, freshness, zones)` payload, so the reducer hydrates
      //    `state.zones` before the session child reads it — no cross-action ordering to get wrong
      //    (Phase 11.4 D2, replacing the old separate zones-action-before-brief-action hazard).
      await send(._generating)
      do {
        async let dwell: Void = clock.sleep(for: Self.loadingPhaseMinDuration)
        async let zonesResult = try? await profileRepository.zones()
        let brief = try await briefRepository.dailyBrief(refresh)
        let zones = await zonesResult
        try? await dwell
        await send(._briefResolved(brief, brief.cached ? .cached : .fresh, zones))
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
