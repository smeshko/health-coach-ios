import BriefRepository
import ComposableArchitecture
import DomainModels
import Foundation
import ProfileRepository
import SyncRepository

// The Today orchestration effects + reducer helpers (Phase 12.1), split out of `TodayFeature.swift` to
// keep that file and the reducer-struct body within the lint length caps. The cache-first contract lives
// here: `orchestrationEffect` (blocking, post-save / retry), `cacheFirstOpenEffect` (app-open peek →
// instant render + quiet background refresh), `backgroundRefreshEffect` (pull-to-refresh / scene
// staleness), and the pure state helpers (`hydrate` / `mergeZones` / `contentEquals` / `isStale`).
extension TodayFeature {
  /// Today in the Europe/Sofia frame (the pinned `\.calendar`/`\.date`, CoachCore) — the key the
  /// orchestration reads the check-in / persisted pick for.
  var today: Date { calendar.startOfDay(for: date.now) }

  /// The morning orchestration as **one** chained, cancellable effect (D15/§11): the check-in **gate**
  /// (no check-in saved today → `.checkInRequired`, **STOP** — no sync; "Save & build today's brief"
  /// re-enters) → `sync()` (must precede the brief; on failure set `.syncFailed` and **STOP** — the
  /// brief closure is never reached, D23/§11) → `dailyBrief(refresh:)`. The post-save / retry path; the
  /// app-open path is `cacheFirstOpenEffect`. A new trigger cancels the in-flight run (`cancelInFlight`)
  /// so a stale brief can't land after a newer request. Each `await` carries the typed catch **plus a
  /// catch-all**: a 401 propagates from `sync()` as **not** a `SyncError` (session-stream-handled,
  /// §13/D13), so the catch-all maps any unexpected throw to a terminal retryable state.
  ///
  /// Takes `state` **inout** to stamp `contentDay` (Phase 19.3, DECISIONS D2): the two orchestration
  /// factories are the single conceptual write point, so every reducer trigger site inherits the stamp.
  func orchestrationEffect(_ state: inout State, refresh: Bool) -> Effect<Action> {
    let rolloverCancels = rolloverGuardOnEntry(&state)
    let day = today
    state.contentDay = day
    let deps = OrchestrationDeps(sync: syncRepository, brief: briefRepository, profile: profileRepository)
    let chain: Effect<Action> = .run { [checkInRepository, sessionSelectionRepository, clock] send in
      // 1. The check-in gates the chain (2026-06-10 design): nothing saved today → show the check-in
      //    screen and stop. A read error degrades to the same gate (the user saves their way through).
      let existing = await (try? checkInRepository.current(day)) ?? nil
      // Race guard (Phase 12.1, DECISIONS D4): make the cooperative-cancellation contract explicit after
      // each awaited boundary, so a `cancelSyncTapped` mid-flight can't deliver a late terminal send.
      try Task.checkCancellation()
      guard existing != nil else {
        await send(._checkInRequired)
        return
      }
      // Restore the day's persisted pick before the brief hydrates, so the carousel opens on it (DECISIONS
      // D4/D5). Sent only when present; a read error / no pick is a silent no-op (the primary stays selected).
      if let restored = await (try? sessionSelectionRepository.current(day)) ?? nil {
        await send(._selectionLoaded(restored))
      }
      await runBlockingChain(refresh: refresh, send: send, clock: clock, deps: deps)
    }
    .cancellable(id: CancelID.orchestration, cancelInFlight: true)
    return .merge(rolloverCancels, chain)
  }

  /// Cache-first app-open (Phase 12.1, revised D15) as **one** chained, cancellable effect: the check-in
  /// **gate** (unchanged, still first) → `cachedDailyBrief()` peek. On a HIT, render the cached brief
  /// immediately (`._cachedBriefLoaded(brief, startBackgroundRefresh: true)`) and continue in the same
  /// effect with a quiet background pass (sync → `dailyBrief(refresh: false)`, with `zones()` riding
  /// alongside). The pass never forces regeneration: a forced `refresh: true` here made every app open
  /// burn an LLM call and let the non-deterministic session pick flip between opens (2026-07-26 incident);
  /// forced regeneration is reserved for explicit intent — pull-to-refresh and the check-in save.
  /// On a MISS (nil, or a peek error treated as a miss) fall through to the **blocking** chain
  /// verbatim — its 1s dwell and `.syncing`/`.generating` screens are the honest first-of-the-day flow.
  /// One `CancelID.orchestration` covers the whole open path (D7).
  ///
  /// Takes `state` **inout** to stamp `contentDay` (Phase 19.3, DECISIONS D2) — see `orchestrationEffect`.
  func cacheFirstOpenEffect(_ state: inout State) -> Effect<Action> {
    let rolloverCancels = rolloverGuardOnEntry(&state)
    let day = today
    state.contentDay = day
    let deps = OrchestrationDeps(sync: syncRepository, brief: briefRepository, profile: profileRepository)
    let chain: Effect<Action> = .run { [checkInRepository, sessionSelectionRepository, briefRepository, clock] send in
      // The check-in gates the chain (unchanged) — a read error degrades to the gate, exactly as before.
      let existing = await (try? checkInRepository.current(day)) ?? nil
      try Task.checkCancellation()
      guard existing != nil else {
        await send(._checkInRequired)
        return
      }
      // Restore the day's persisted pick before any hydration, so both the cache-hit and miss branches seed
      // the carousel on it (DECISIONS D4/D5). Sent only when present; no pick is a silent no-op.
      if let restored = await (try? sessionSelectionRepository.current(day)) ?? nil {
        await send(._selectionLoaded(restored))
      }
      // The pure same-day peek (DECISIONS D1) — a throw is treated as a cache miss (the blocking path
      // will surface any real failure honestly).
      guard let cached = try? await briefRepository.cachedDailyBrief() else {
        // MISS → the blocking sync→generate chain, unchanged.
        await runBlockingChain(refresh: false, send: send, clock: clock, deps: deps)
        return
      }
      // HIT → render immediately + start the background refresh in this same effect.
      await send(._cachedBriefLoaded(cached, startBackgroundRefresh: true))
      await runBackgroundPass(refresh: false, send: send, deps: deps)
    }
    .cancellable(id: CancelID.orchestration, cancelInFlight: true)
    return .merge(rolloverCancels, chain)
  }

  /// The stamp-write entry guard (review #3.2): an orchestration entered WITHOUT a scene
  /// re-activation — a post-midnight save or retry on a continuously active scene — would otherwise
  /// move `contentDay` over a stale day and permanently mask the rollover, carrying yesterday's
  /// `restoredSelection` (and any resident children) into today's hydrate. Detect it exactly like
  /// `sceneActivated`'s rollover leg: reset the per-day state and cancel the check-in child's
  /// in-flight effects before the factory stamps and runs. Same-day entries (the overwhelmingly
  /// common case) find `contentDay == today` (or `nil` on first run) and are untouched.
  private func rolloverGuardOnEntry(_ state: inout State) -> Effect<Action> {
    guard let contentDay = state.contentDay, contentDay != today else { return .none }
    log.info("Orchestration entry — stale contentDay, resetting per-day state", category: .lifecycle)
    Self.rolloverReset(&state)
    return .merge(
      .cancel(id: CheckInComponent.CancelID.load),
      .cancel(id: CheckInComponent.CancelID.save)
    )
  }

  /// The quiet background-refresh pass, shared by pull-to-refresh and the scene-staleness trigger
  /// (Phase 12.1). The open-path hit runs its pass INSIDE `cacheFirstOpenEffect` (so this is NOT returned
  /// from `._cachedBriefLoaded`, which would cancel that in-flight pass). Runs on `CancelID.orchestration`.
  /// `refresh` is `true` only for pull-to-refresh (explicit intent); the scene-staleness trigger passes
  /// `false` — a mere re-foreground must not force an LLM regeneration (cost + session-pick churn).
  func backgroundRefreshEffect(refresh: Bool) -> Effect<Action> {
    .run { [syncRepository, briefRepository, profileRepository] send in
      await runBackgroundPass(
        refresh: refresh,
        send: send,
        deps: OrchestrationDeps(sync: syncRepository, brief: briefRepository, profile: profileRepository)
      )
    }
    .cancellable(id: CancelID.orchestration, cancelInFlight: true)
  }

  /// Persist the committed workout pick by value for today (DECISIONS D4/D5) — a fire-and-forget local
  /// write. Best-effort: a failure is swallowed (`try?`) so it never breaks the UI; the live session child's
  /// `selectedSession` already carries the pick for any in-session background re-seed.
  func persistSelectionEffect(_ block: SessionBlock) -> Effect<Action> {
    let day = today
    return .run { [sessionSelectionRepository] _ in
      try? await sessionSelectionRepository.save(block, day)
    }
  }

  // MARK: - Reducer helpers (Phase 12.1)

  /// The scene re-activation detector (Phase 12.1 DECISIONS D6 / Phase 19.3 D1–D2) — two legs:
  ///
  /// **Rollover leg:** compares the `contentDay` stamp — ONE detector over every stamped state, so
  /// yesterday's terminals (`.ready`, `.checkInRequired`, `.error`, `.syncFailed`) AND an
  /// overnight-suspended in-flight chain (`.syncing`/`.generating`) all reset + re-orchestrate (the
  /// restart is safe: `cacheFirstOpenEffect` is `cancelInFlight` on the shared orchestration CancelID;
  /// the new day's gate/loading are the explicit no-loading-over-content exemption). A `nil` stamp
  /// (orchestration never ran) must NOT trigger it — fresh state falls through to the staleness leg.
  ///
  /// **Same-day staleness leg:** stays `.ready`-gated exactly as before Phase 19.3 —
  /// `isStale(nil, nil) == true`, so widening it would fire a background refresh over a same-day
  /// `.checkInRequired`. It never stamps `contentDay` (a background pass must not mask a rollover, D2).
  func sceneActivated(_ state: inout State) -> Effect<Action> {
    if let contentDay = state.contentDay, contentDay != today {
      // Day rollover: yesterday's content (whatever terminal or in-flight shape it is in) is stale →
      // re-run the full cache-first orchestration. Its entry guard (`rolloverGuardOnEntry`) performs
      // the reset AND cancels the check-in child's in-flight effects (reviews #1.1/#3.2) — the reset
      // alone is not an async barrier: a pre-midnight load/save suspended across midnight would
      // otherwise deliver into the freshly reset state.
      log.info("Scene active — day rollover", category: .lifecycle)
      return cacheFirstOpenEffect(&state)
    }
    // Same day (or no stamp yet): refresh only over a rendered brief whose freshness reference is past
    // the staleness threshold. `lastRefreshAttemptAt` (recorded below) throttles a failed refresh.
    guard case .ready = state.briefState else { return .none }
    guard Self.isStale(
      now: date.now, threshold: Self.backgroundRefreshStaleness,
      lastSyncedAt: state.lastSyncedAt, lastRefreshAttemptAt: state.lastRefreshAttemptAt
    ) else { return .none }
    log.info("Scene active — stale, starting background refresh", category: .lifecycle)
    state.isBackgroundRefreshing = true
    state.lastRefreshAttemptAt = date.now
    return backgroundRefreshEffect(refresh: false)
  }

  /// The per-day state contract (Phase 19.3, DECISIONS D1) — everything belonging to ONE Sofia day,
  /// cleared by `rolloverGuardOnEntry` (every orchestration entry that finds a stale `contentDay`,
  /// review #3.2) before re-orchestration: the check-in child (answers,
  /// `existing`, the "Last saved" footer), the session carousel + the restored pick (yesterday's pick
  /// must never seed today's carousel), the readiness card, and the refresh throttle.
  /// `isBackgroundRefreshing` clears too: the rollover's `cancelInFlight` kills an in-flight background
  /// pass, so its resolved/failed action never arrives to clear the flag — a stuck "Updating…" pill
  /// otherwise. **Survivors, deliberately:** `zones` (profile-derived — 19.2 refreshes them per-sync,
  /// not per-day) and `lastSyncedAt` (mirrors the sync watermark — a fact about the store, not the
  /// day). `contentDay` itself is re-stamped by the factory the detector invokes next.
  static func rolloverReset(_ state: inout State) {
    state.checkIn = CheckInComponent.State()
    state.session = nil
    state.restoredSelection = nil
    state.readiness = nil
    state.lastRefreshAttemptAt = nil
    state.isBackgroundRefreshing = false
  }

  /// Hydrate `.ready(brief, freshness)` + the readiness/session children from a resolved brief — the
  /// single source of the child-seeding mutation shared by `._briefResolved`, `._cachedBriefLoaded`, and
  /// the changed-brief `._backgroundRefreshResolved` path. A tripped safety gate leaves `session` nil (the
  /// inline `SafetyRestView` renders instead); the session child reads whatever `state.zones` currently
  /// holds (the background zone-merge fills a cold-open's nil afterward).
  func hydrate(_ state: inout State, from brief: DomainModels.DailyBrief, freshness: Freshness) {
    state.briefState = .ready(brief, freshness)
    state.readiness = ReadinessComponent.State(readiness: brief.readiness)
    guard !brief.safetyGate.triggered else {
      state.session = nil
      return
    }
    // Seed the committed pick by value (DECISIONS D4): prefer the live child's current selection so a
    // background re-seed of a changed brief preserves a still-valid choice; on the first hydrate (no child
    // yet) fall back to the app-open `restoredSelection`. A block no longer among the candidates falls back
    // to the primary (index 0) — the same degrade `selectedSession` applies to a stale index.
    let candidates = [brief.session] + brief.alternatives
    let preferred = state.session?.selectedSession ?? state.restoredSelection
    let selectedIndex = preferred.flatMap { candidates.firstIndex(of: $0) } ?? 0
    state.session = SessionFeature.State(
      session: brief.session,
      alternatives: brief.alternatives,
      skipOk: brief.skipOk,
      narrative: brief.narrative.filter { $0.type == .session },
      zones: state.zones,
      selectedIndex: selectedIndex
    )
  }

  /// Merge a non-nil zones into the parent + the live session child IN PLACE (DECISIONS D3), preserving
  /// the child's swap/expansion UI state. A nil fetch keeps previously held zones.
  func mergeZones(_ state: inout State, _ zones: Zones?) {
    guard let zones else { return }
    state.zones = zones
    state.session?.zones = zones
  }

  /// Content equality for the background swap (DECISIONS D3): two briefs are "the same content" when they
  /// match after normalizing the **non-rendered metadata** — `generatedAt`, `cached`, and
  /// `constitutionVersion` (debug metadata per the PRD). A forced regeneration always returns a fresh
  /// `generatedAt`, so plain `==` would read every refresh as changed and needlessly re-seed children.
  func contentEquals(_ lhs: DomainModels.DailyBrief, _ rhs: DomainModels.DailyBrief) -> Bool {
    normalizedMetadata(lhs) == normalizedMetadata(rhs)
  }

  /// A copy of `brief` with the non-rendered metadata neutralized (DECISIONS D3) — the comparison basis
  /// for `contentEquals`.
  private func normalizedMetadata(_ brief: DomainModels.DailyBrief) -> DomainModels.DailyBrief {
    var normalized = brief
    normalized.generatedAt = .distantPast
    normalized.cached = false
    normalized.constitutionVersion = nil
    return normalized
  }

  /// The pure scene-staleness comparison (DECISIONS D6), threshold/timestamp-injectable so it's testable
  /// without a TestStore: the freshness reference is `max(lastSyncedAt, lastRefreshAttemptAt)`; the
  /// activation is stale when that reference is older than `threshold`, and when **both** timestamps are
  /// nil (a fresh open that never synced — nil-is-stale, throttled by `lastRefreshAttemptAt`).
  static func isStale(
    now: Date, threshold: Duration, lastSyncedAt: Date?, lastRefreshAttemptAt: Date?
  ) -> Bool {
    let references = [lastSyncedAt, lastRefreshAttemptAt].compactMap { $0 }
    guard let reference = references.max() else { return true }
    return now.timeIntervalSince(reference) >= Double(threshold.components.seconds)
  }
}

// MARK: - Effect bodies

// Free functions (not reducer methods) so the `@Sendable` effect closures capture only the explicitly
// passed Sendable dependencies, never the non-Sendable `TodayFeature` (its `@Dependency` storage). The
// repositories travel as one `OrchestrationDeps` bundle to keep the call sites + signatures tidy.

/// The Sendable dependency bundle the free orchestration helpers run against (the three repositories).
private struct OrchestrationDeps {
  let sync: SyncRepository
  let brief: BriefRepository
  let profile: ProfileRepository
}

/// The blocking sync→generate chain body (the gate is already passed). Mirrors the pre-12.1 orchestration
/// steps 2–3; shared by `orchestrationEffect` (post-save / retry) and `cacheFirstOpenEffect`'s miss branch.
private func runBlockingChain(
  refresh: Bool,
  send: Send<TodayFeature.Action>,
  clock: any Clock<Duration>,
  deps: OrchestrationDeps
) async {
  let syncRepository = deps.sync
  let briefRepository = deps.brief
  let profileRepository = deps.profile
  await send(._syncStarted)
  do {
    async let dwell: Void = clock.sleep(for: TodayFeature.loadingPhaseMinDuration)
    _ = try await syncRepository.sync()
    try? await dwell
    try Task.checkCancellation()
  } catch is CancellationError {
    return
  } catch let error as SyncError {
    await send(._syncFailed(error))
    return
  } catch {
    await send(._syncFailed(.transient))
    return
  }
  await send(._generating)
  do {
    async let dwell: Void = clock.sleep(for: TodayFeature.loadingPhaseMinDuration)
    async let zonesResult = try? await profileRepository.zones()
    let brief = try await briefRepository.dailyBrief(refresh)
    let zones = await zonesResult
    try? await dwell
    try Task.checkCancellation()
    await send(._briefResolved(brief, brief.cached ? .cached : .fresh, zones))
  } catch is CancellationError {
    return
  } catch let error as BriefError {
    await send(._briefFailed(error))
  } catch {
    await send(._briefFailed(.transientGenerationFailed))
  }
}

/// The quiet background pass (sync → record → brief, with zones alongside) — Phase 12.1. A pre-sync
/// zones read starts ALONGSIDE `sync()` (`ProfileRepository.zones()` is cache-first, so cached zones
/// survive a failing sync, DECISIONS D3 round-3 #2); a `sync()` success records `lastSyncedAt` via
/// `._backgroundSyncCompleted`; `dailyBrief(refresh:)` resolves through
/// `._backgroundRefreshResolved` (swap-if-changed) or, on any throw, `._backgroundRefreshFailed` — both
/// merging fetched zones. `refresh` is `true` only for pull-to-refresh: the open and scene-staleness
/// passes pass `false` so a routine open never forces an LLM regeneration (the pre-2026-07-26 hardcoded
/// `true` regenerated — and could flip — the brief on every open). A SECOND `zones()` read starts right
/// after a successful sync (Phase 19.2 review rounds 1–2): that sync just advanced the watermark
/// `serverTime`, so the post-sync read is the one that picks up recomputed constants in the same pass,
/// on both the resolved and the failed-brief paths — the pre-sync value is only the nil fallback.
/// No min-dwell.
private func runBackgroundPass(
  refresh: Bool,
  send: Send<TodayFeature.Action>,
  deps: OrchestrationDeps
) async {
  let syncRepository = deps.sync
  let briefRepository = deps.brief
  let profileRepository = deps.profile
  async let preSyncZones = try? await profileRepository.zones()
  do {
    _ = try await syncRepository.sync()
    try Task.checkCancellation()
  } catch is CancellationError {
    return
  } catch {
    // Sync failed → the watermark did not advance; the pre-sync cached zones are still current.
    await send(._backgroundRefreshFailed(await preSyncZones))
    return
  }
  await send(._backgroundSyncCompleted)
  // Post-sync read (19.2 sync-anchored staleness): the watermark just advanced, so this call refetches
  // the recomputed profile. Started alongside the brief so a brief failure still delivers it.
  async let postSyncZonesResult = try? await profileRepository.zones()
  do {
    let brief = try await briefRepository.dailyBrief(refresh)
    var zones = await postSyncZonesResult
    if zones == nil { zones = await preSyncZones }
    try Task.checkCancellation()
    await send(._backgroundRefreshResolved(brief, zones))
  } catch is CancellationError {
    return
  } catch {
    // The brief failure degrades quietly; the post-sync (recomputed) zones still merge.
    var zones = await postSyncZonesResult
    if zones == nil { zones = await preSyncZones }
    await send(._backgroundRefreshFailed(zones))
  }
}
