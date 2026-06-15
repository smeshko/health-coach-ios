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
  func orchestrationEffect(refresh: Bool) -> Effect<Action> {
    let day = today
    let deps = OrchestrationDeps(sync: syncRepository, brief: briefRepository, profile: profileRepository)
    return .run { [checkInRepository, sessionSelectionRepository, clock] send in
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
  }

  /// Cache-first app-open (Phase 12.1, revised D15) as **one** chained, cancellable effect: the check-in
  /// **gate** (unchanged, still first) → `cachedDailyBrief()` peek. On a HIT, render the cached brief
  /// immediately (`._cachedBriefLoaded(brief, startBackgroundRefresh: true)`) and continue in the same
  /// effect with a quiet background pass (sync → `dailyBrief(refresh: true)`, with `zones()` riding
  /// alongside). On a MISS (nil, or a peek error treated as a miss) fall through to the **blocking** chain
  /// verbatim — its 1s dwell and `.syncing`/`.generating` screens are the honest first-of-the-day flow.
  /// One `CancelID.orchestration` covers the whole open path (D7).
  func cacheFirstOpenEffect() -> Effect<Action> {
    let day = today
    let deps = OrchestrationDeps(sync: syncRepository, brief: briefRepository, profile: profileRepository)
    return .run { [checkInRepository, sessionSelectionRepository, briefRepository, clock] send in
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
      await runBackgroundPass(send: send, deps: deps)
    }
    .cancellable(id: CancelID.orchestration, cancelInFlight: true)
  }

  /// The quiet background-refresh pass, shared by pull-to-refresh and the scene-staleness trigger
  /// (Phase 12.1). The open-path hit runs its pass INSIDE `cacheFirstOpenEffect` (so this is NOT returned
  /// from `._cachedBriefLoaded`, which would cancel that in-flight pass). Runs on `CancelID.orchestration`.
  func backgroundRefreshEffect() -> Effect<Action> {
    .run { [syncRepository, briefRepository, profileRepository] send in
      await runBackgroundPass(
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

/// The quiet background pass (sync → record → brief, with zones alongside) — Phase 12.1. Zones start
/// ALONGSIDE `sync()` (`ProfileRepository.zones()` is cache-first, so cached zones survive a failing sync,
/// DECISIONS D3 round-3 #2); a `sync()` success records `lastSyncedAt` via `._backgroundSyncCompleted`;
/// `dailyBrief(refresh: true)` (D2) resolves through `._backgroundRefreshResolved` (swap-if-changed) or,
/// on any throw, `._backgroundRefreshFailed` — both merging already-fetched zones. No min-dwell.
private func runBackgroundPass(
  send: Send<TodayFeature.Action>,
  deps: OrchestrationDeps
) async {
  let syncRepository = deps.sync
  let briefRepository = deps.brief
  let profileRepository = deps.profile
  async let zonesResult = try? await profileRepository.zones()
  do {
    _ = try await syncRepository.sync()
    try Task.checkCancellation()
    await send(._backgroundSyncCompleted)
    let brief = try await briefRepository.dailyBrief(true)
    let zones = await zonesResult
    try Task.checkCancellation()
    await send(._backgroundRefreshResolved(brief, zones))
  } catch is CancellationError {
    return
  } catch {
    // Any failure (sync or brief) degrades quietly; already-fetched zones still merge.
    await send(._backgroundRefreshFailed(await zonesResult))
  }
}
