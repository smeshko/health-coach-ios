import BriefRepository
import ComposableArchitecture
import DomainModels
import Foundation
import LocalRepositories
import LogClient
import ProfileRepository
import SyncRepository

/// The Today tab's root reducer (ARCHITECTURE §4.5, PRD §6/§8.1) — the hero "daily brief" screen. It owns
/// the universal `BriefViewState` lifecycle (the single source of truth, DECISIONS #1) and the app-open
/// orchestration. **Cache-first on open (Phase 12.1, revised D15/§11):** a same-day **cached** brief
/// renders immediately (the `cachedDailyBrief` peek) with a quiet background sync → `dailyBrief(refresh:)`
/// that swaps in only if the content changed; the blocking sync → generate chain (**sync strictly before
/// a *generated* brief**) runs only on a cache miss / post-save / explicit retry. The check-in **gates**
/// the chain in every branch (the 2026-06-10 design iteration, superseding PRD §7.2's never-blocks rule):
/// no check-in saved today → `.checkInRequired` (the check-in screen, no sync); "Save & build today's
/// brief" re-enters the blocking chain with `refresh: true`. The orchestration effects + reducer helpers
/// live in `TodayOrchestration.swift`. The 8.2/8.3/8.4 sub-sections plug into stable seams under `ready`.
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
    /// True while a **quiet background refresh** (the cache-first open's post-hit pass, pull-to-refresh, or
    /// the scene-staleness pass) is in flight (Phase 12.1). Drives the header's "Updating…" pill; never a
    /// loading wall over visible content.
    public var isBackgroundRefreshing: Bool
    /// The instant the most recent background refresh **started** (Phase 12.1, DECISIONS D6). The second
    /// leg of the staleness throttle: a cache-hit open whose background `sync()` fails leaves `lastSyncedAt`
    /// nil, so the scene-staleness gate compares `max(lastSyncedAt, lastRefreshAttemptAt)` — without this a
    /// failed refresh would re-fire on every activation (flap-prone).
    public var lastRefreshAttemptAt: Date?
    /// The day's persisted workout pick, restored at app open (`._selectionLoaded`) and consumed by the
    /// first `hydrate` to seed the carousel's `selectedIndex` by value (DECISIONS D4/D5). Thereafter the
    /// session child's own `selectedSession` is what a background re-seed preserves, so this lingers unused.
    public var restoredSelection: SessionBlock?
    /// The Sofia `startOfDay` the current content was orchestrated for (Phase 19.3, DECISIONS D2) —
    /// stamped ONLY by the `inout` orchestration-effect factories (one conceptual write point; background
    /// triggers deliberately never stamp) and read by `sceneActivated`'s rollover leg, so yesterday's
    /// terminals (`.checkInRequired`/`.error`/`.syncFailed`) and in-flight states are rollover-detectable,
    /// not just `.ready`. `nil` (orchestration never ran) never triggers the rollover leg.
    public var contentDay: Date?

    public init(
      briefState: BriefViewState = .idle,
      checkIn: CheckInComponent.State = CheckInComponent.State(),
      readiness: ReadinessComponent.State? = nil,
      session: SessionFeature.State? = nil,
      zones: Zones? = nil,
      selectedSection: TodaySection = .exercise,
      lastSyncedAt: Date? = nil,
      isBackgroundRefreshing: Bool = false,
      lastRefreshAttemptAt: Date? = nil,
      restoredSelection: SessionBlock? = nil,
      contentDay: Date? = nil
    ) {
      self.briefState = briefState
      self.checkIn = checkIn
      self.readiness = readiness
      self.session = session
      self.zones = zones
      self.selectedSection = selectedSection
      self.lastSyncedAt = lastSyncedAt
      self.isBackgroundRefreshing = isBackgroundRefreshing
      self.lastRefreshAttemptAt = lastRefreshAttemptAt
      self.restoredSelection = restoredSelection
      self.contentDay = contentDay
    }
  }

  public enum Action {
    /// Sent by the host on app-open — drives the cache-first orchestration (Phase 12.1): a same-day
    /// cached brief renders immediately with a quiet background refresh; a miss runs the blocking chain.
    case onAppOpen
    /// Retry from a `.syncFailed`/`.error` terminal — re-runs the full **blocking** sync-first chain.
    case retryTapped
    /// Pull-to-refresh from `.ready` (Phase 12.1) — runs the quiet background-refresh pass; a no-op in any
    /// other state.
    case pullToRefresh
    /// Scene re-activation (Phase 12.1 D6 / Phase 19.3): a `contentDay` rollover resets the per-day
    /// state and re-orchestrates from ANY stamped state (terminals and in-flight alike); a stale
    /// same-day `.ready` brief background-refreshes quietly; otherwise nothing.
    case sceneBecameActive
    /// Cancel the (now-rare) blocking sync/generate screen (Phase 12.1, DECISIONS D4) — cancels the
    /// orchestration and falls back to the cached brief when one exists, else `.syncFailed(.transient)`.
    case cancelSyncTapped
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
    /// The day's persisted workout pick, restored at app open BEFORE the brief hydrates (DECISIONS D4/D5) —
    /// stashed in `restoredSelection` for the next `hydrate`. Sent **only** when a pick exists.
    case _selectionLoaded(SessionBlock)
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
    // Phase 12.1 cache-first open actions (DECISIONS D3).
    /// A same-day cache **hit**: render `.ready(brief, .cached)` and hydrate the readiness/session children
    /// (exactly as `._briefResolved` does). `startBackgroundRefresh` splits "hydrate + start refresh" (the
    /// app-open hit) from "hydrate only" (the cancel fallback, D4) without duplicating the hydration.
    case _cachedBriefLoaded(DomainModels.DailyBrief, startBackgroundRefresh: Bool)
    /// The background `sync()` succeeded — record `lastSyncedAt` immediately (mirrors the blocking path's
    /// record-on-sync-success), so a later brief-refresh failure can't hide a truthful "Synced X ago" pill.
    case _backgroundSyncCompleted
    /// The background `dailyBrief(refresh: true)` resolved. Merge any non-nil zones, then **content-equality**
    /// (D3): unchanged → children untouched (flag cleared, freshness/cached-label metadata may update);
    /// changed → full `._briefResolved`-style re-hydration to `.ready(brief, .fresh)`.
    case _backgroundRefreshResolved(DomainModels.DailyBrief, Zones?)
    /// The background pass threw — quiet degrade: merge any already-fetched zones, clear the flag, stay
    /// `.ready` with the prior truthful sync status. `lastSyncedAt` keeps whatever the sync step recorded.
    case _backgroundRefreshFailed(Zones?)
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

  /// How old the freshness reference (`max(lastSyncedAt, lastRefreshAttemptAt)`) may be before a scene
  /// re-activation triggers a quiet background refresh (Phase 12.1, DECISIONS D6). 15 minutes balances
  /// HealthKit data drift against API cost; a named constant so product can tune it and tests advance a
  /// `TestClock`/`\.date` deterministically.
  static let backgroundRefreshStaleness: Duration = .seconds(15 * 60)

  @Dependency(\.checkInRepository) var checkInRepository
  @Dependency(\.syncRepository) var syncRepository
  @Dependency(\.briefRepository) var briefRepository
  @Dependency(\.sessionSelectionRepository) var sessionSelectionRepository
  @Dependency(\.profileRepository) var profileRepository
  @Dependency(\.continuousClock) var clock
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date
  @Dependency(\.log) var log

  public init() {}

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
        // Cache-first open (Phase 12.1, revised D15): check-in gate → cache peek → on a HIT render the
        // cached brief immediately and refresh quietly in the background; on a MISS the blocking
        // sync→generate chain runs unchanged.
        log.info("App-open — starting cache-first orchestration", category: .lifecycle)
        return cacheFirstOpenEffect(&state)

      case .retryTapped:
        // Retry from a terminal — re-runs the **blocking** sync-first chain (open path, `refresh: false`).
        // An explicit retry is an honest loading moment, so it never peeks the cache.
        return orchestrationEffect(&state, refresh: false)

      case .pullToRefresh:
        // Manual refresh (Phase 12.1) — only meaningful over a rendered brief; a no-op otherwise so the
        // gesture can't enter a loading state. Shares the background-refresh effect with the open path.
        guard case .ready = state.briefState else { return .none }
        log.info("Pull-to-refresh — starting background refresh", category: .lifecycle)
        state.isBackgroundRefreshing = true
        state.lastRefreshAttemptAt = date.now
        return backgroundRefreshEffect()

      case .sceneBecameActive:
        // The two-leg detector (rollover reset over any stamped state + the `.ready`-gated same-day
        // staleness refresh) lives in `TodayOrchestration.swift` (Phase 12.1 D6 / Phase 19.3 D1–D2).
        return sceneActivated(&state)

      case .cancelSyncTapped:
        // Cancel the blocking sync/generate screen (Phase 12.1, DECISIONS D4) — only meaningful while a
        // loading screen is up. Cancel the in-flight orchestration, THEN peek the cache (`.concatenate`
        // so the peek can't race the dying chain's sends): a hit → hydrate-only `.ready(cached, .cached)`,
        // a miss → `.syncFailed(.transient)` + Retry. The fallbacks are state-gated in their handlers so a
        // brief that landed just before the cancel isn't stomped.
        guard state.briefState == .syncing || state.briefState == .generating else { return .none }
        log.info("Cancel tapped — stopping blocking sync", category: .lifecycle)
        return .concatenate(
          .cancel(id: CancelID.orchestration),
          .run { [briefRepository] send in
            if let cached = try? await briefRepository.cachedDailyBrief() {
              await send(._cachedBriefLoaded(cached, startBackgroundRefresh: false))
            } else {
              await send(._syncFailed(.transient))
            }
          }
          // Register the peek under the orchestration ID so a superseding trigger (e.g. a day-rollover
          // `sceneBecameActive`) that fires inside this DB read drops it — otherwise its late
          // `._cachedBriefLoaded` could stomp the new chain's `.syncing` (review #1).
          .cancellable(id: CancelID.orchestration, cancelInFlight: true)
        )

      case let ._selectionLoaded(block):
        // Stash the restored pick so the next `hydrate` seeds the carousel on it (DECISIONS D4). Arrives
        // before the brief actions in the same open effect, so `restoredSelection` is set when `hydrate` runs.
        state.restoredSelection = block
        return .none

      case ._checkInRequired:
        state.briefState = .checkInRequired
        return .none

      case ._syncStarted:
        state.briefState = .syncing
        return .none

      case let ._syncFailed(error):
        // Block-and-retry: the brief was never requested (D23/§11). State-gated (Phase 12.1, D4): only a
        // loading screen transitions to the terminal — so the cancel-path `.syncFailed` can't stomp a
        // brief that landed just before the cancel (it would already be `.ready`).
        guard state.briefState == .syncing || state.briefState == .generating else { return .none }
        state.briefState = .syncFailed(error)
        return .none

      case ._generating:
        // Reaching `.generating` means `sync()` succeeded → record the sync time (the header pill's
        // source) and move to the brief request.
        state.lastSyncedAt = date.now
        state.briefState = .generating
        return .none

      case let ._briefResolved(brief, freshness, zones):
        // Hydrate `state.zones` FIRST, from this single payload, so the session child reads it while
        // hydrating (DECISIONS #4 / Phase 11.4 D2 — one resolved payload, no cross-action ordering). A
        // `nil` fetch degrades silently (no zone chip).
        state.zones = zones
        hydrate(&state, from: brief, freshness: freshness)
        return .none

      case let ._briefFailed(error):
        state.briefState = .error(error)
        return .none

      case let ._cachedBriefLoaded(brief, startBackgroundRefresh):
        // State-gated (Phase 12.1, D4): the cancel fallback's hydrate-only variant must not stomp a brief
        // that landed just before the cancel. The app-open hit (where this runs over `.idle`) and the
        // cancel fallback (over a loading screen) are both allowed; a `.ready` already shows a brief.
        if !startBackgroundRefresh {
          guard state.briefState == .syncing || state.briefState == .generating else { return .none }
        }
        // Render the cached same-day brief immediately (no loading wall) — `.cached` keeps the
        // "Cached — as of HH:MM" label honest until a background refresh swaps in a fresh brief. Zones are
        // still nil on a cold open; the background pass's zone merge fills the HR chip in place.
        hydrate(&state, from: brief, freshness: .cached)
        // `startBackgroundRefresh` only flips the status flags — the background pass itself runs INSIDE the
        // same `cacheFirstOpenEffect` that sent this action (one `CancelID.orchestration` chain, D7), so we
        // must NOT return a second `backgroundRefreshEffect()` here (it would cancel the in-flight pass via
        // `cancelInFlight`). The cancel fallback uses `startBackgroundRefresh: false` (hydrate only).
        if startBackgroundRefresh {
          state.isBackgroundRefreshing = true
          state.lastRefreshAttemptAt = date.now
        }
        return .none

      case ._backgroundSyncCompleted:
        // The background `sync()` succeeded → record the sync time immediately (mirrors `._generating`),
        // so a later brief-refresh failure still shows a truthful "Synced X ago" pill (DECISIONS D6).
        state.lastSyncedAt = date.now
        return .none

      case let ._backgroundRefreshResolved(brief, zones):
        state.isBackgroundRefreshing = false
        // Always merge a non-nil zones into the parent + the live session child IN PLACE (DECISIONS D3,
        // round-2 #1): the cold cache-hit open hydrated the child before any zones existed, so this is
        // what makes the HR chip appear — and it preserves the child's swap/expansion UI state. A nil
        // fetch keeps previously held zones.
        mergeZones(&state, zones)
        // Only act over a still-rendered `.ready` brief. If the state moved on (e.g. a day-rollover
        // re-orchestration put a loading screen back up), this background result is stale — drop it
        // rather than hydrate over a non-`.ready` state (defensive; the shared `CancelID.orchestration`
        // normally makes this unreachable, but keep the terminal symmetric with the gated fallbacks).
        guard case let .ready(current, _) = state.briefState else { return .none }
        // Content equality (DECISIONS D3): an unchanged brief leaves the children untouched (only the
        // freshness/cached-label metadata may shift); a changed brief re-seeds them via the full
        // hydration (same semantics as a fresh generation).
        guard contentEquals(current, brief) else {
          hydrate(&state, from: brief, freshness: .fresh)
          return .none
        }
        // Unchanged content: keep children, but reflect the regenerated brief's freshness metadata
        // (a forced regeneration returns `cached == false`), so the cached label clears honestly.
        state.briefState = .ready(brief, brief.cached ? .cached : .fresh)
        return .none

      case let ._backgroundRefreshFailed(zones):
        // Quiet degrade (DECISIONS D3/D6): merge any already-fetched zones, clear the flag, stay `.ready`
        // with the prior truthful sync status. `lastSyncedAt` keeps whatever `._backgroundSyncCompleted`
        // recorded (sync ok, brief failed → pill shows "Synced X ago"; sync failed → nil, pill hidden).
        log.info("Background refresh failed — degrading quietly", category: .lifecycle)
        state.isBackgroundRefreshing = false
        mergeZones(&state, zones)
        return .none

      case .checkIn(.delegate(.checkInSaved)):
        // "Save & build today's brief" — the saved check-in unlocks the gate, so re-enter the chain with
        // `refresh: true` (a corrected check-in regenerates the brief rather than serving the cache).
        log.info("Check-in saved — building today's brief", category: .lifecycle)
        return orchestrationEffect(&state, refresh: true)

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

      case let .session(.delegate(.selectionChanged(block))):
        // The athlete committed a workout — persist it by value for the day, best-effort (DECISIONS D4/D5).
        log.info("Session selection changed — persisting today's pick", category: .lifecycle)
        return persistSelectionEffect(block)

      case .session:
        // The carousel selection (`cardSelected`) is handled by the scoped child reducer (below).
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
}

/// The Exercise | Nutrition segmented toggle's selection (the 2026-06-10 shell). Top-level (not nested in
/// `TodayFeature`) to stay within the 1-level type-nesting lint rule.
public enum TodaySection: Equatable, Sendable { case exercise, nutrition }
