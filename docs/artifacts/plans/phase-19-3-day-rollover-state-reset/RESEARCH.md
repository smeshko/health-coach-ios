# Research: Day-rollover state reset (Phase 19.3)

Curated findings, 2026-07-10. Sources: audit `docs/artifacts/audits/AUDIT-2026-07-05.md`,
code reads of TodayFeature (staging tip `0dbd551`, post-19.2).

## Rollover detection today

- `TodayFeature.swift:215–224` — `sceneBecameActive`:
  `guard case let .ready(brief, _) = state.briefState else { return .none }`, then
  `calendar.startOfDay(for: brief.date) != today` → `cacheFirstOpenEffect()` with a
  `.lifecycle` log. **No state reset**; and non-`.ready` states (yesterday's
  `.checkInRequired`, `.error`) short-circuit to `.none` — a user who never checked in
  yesterday and reopens today gets NO re-orchestration from this branch (the gate would
  only re-run via a fresh `.task`/app relaunch).
- Same-day branch: `Self.isStale(now:threshold:lastSyncedAt:lastRefreshAttemptAt:)`
  throttled background refresh — pinned by `TodayFeatureSceneStalenessTests`; must stay
  behaviorally untouched.

## Per-day state inventory (`TodayFeature.State`)

| Field | Per-day? | Survives rollover today | Reset in 19.3 |
|---|---|---|---|
| `checkIn: CheckInComponent.State` (`answers`, `existing`, `lastSavedAt`) | yes | yes — footer bug | yes → fresh `.init()` |
| `session: SessionFeature.State?` (computed `selectedSession` = `candidates[selectedIndex]`) | yes | yes — carousel seed bug | yes → `nil` |
| `restoredSelection: SessionBlock?` | yes | yes | yes → `nil` |
| `readiness: ReadinessComponent.State?` | yes | yes | yes → `nil` |
| `lastRefreshAttemptAt: Date?` (failed-refresh throttle) | per-day-ish | yes | yes (rollover branch only) |
| `isBackgroundRefreshing: Bool` (the "Updating…" pill) | in-flight flag | yes — and the rollover's cancelInFlight kills the pass that would clear it (round-1 #1) | yes → `false` |
| `zones: Zones?` | no (19.2 refreshes per-sync) | yes | no |
| `lastSyncedAt: Date?` (watermark mirror) | no | yes | no |
| `briefState` | yes | flips via re-orchestration | via existing flow |

## The two seed paths

- Carousel: `TodayOrchestration.hydrate` (~:117–139) —
  `let preferred = state.session?.selectedSession ?? state.restoredSelection` → index
  into the new day's candidates. Stale in-memory child/restored block = yesterday's pick
  pre-selected. Persistence is NOT the bug: `SessionSelectionRecord` PK = Sofia
  `startOfDay`; a new day reads `nil` and `._selectionLoaded` is only sent when a row
  exists.
- Footer: `CheckInSection.swift:64–69` — `lastSavedAt != nil` → "Last saved <time>",
  else `existing != nil` → "Saved earlier today". Neither is day-guarded;
  `CheckInComponent.State.lastSavedAt` is session-local (set on save success, never
  loaded), `existing` is loaded by the child's `.task` for whatever day it last ran.
- Check-in gate correctness: `CheckInRepositoryLive` normalizes to `startOfDay` and
  fetches by day PK — the gate is right; only the residual child state lies.

## Forced-REST zone chip

- `TodayReadyContent.swift:55–66` — `case let .forcedRest(gate, override):
  SafetyRestView(gate:overrideSession:zoneRange: nil, narrative:)` with the verbatim
  comment: "an `active_recovery` override's Z1 chip is reconciled when that lands."
  Zones landed (Phase 8.4 `_briefResolved` carries `Zones?`; 12.1 background pass;
  19.2 made them refresh per-sync) — the hardcode is the last gap.
- `SafetyRestView` (TodayFeature module, `SafetyRest/SafetyRestView.swift`) — render-only
  value-init view; `zoneRange: ZoneRange?`, `nil` ⇒ no chip; "the view never resolves
  zones itself (§3)" — resolution belongs to the parent.
- Resolution helper exists at `SessionFeature.State.zoneRange(for:)`
  (`Session/SessionFeature.swift:77–86`): exhaustive switch `zone → zones.zN` — but it
  needs the session child, which is `nil` on a tripped day (`session` is only populated
  `!safetyGate.triggered`). Both files are in the SAME module (TodayFeature) → extract
  an internal `extension Zones { func range(for zone: Zone) -> ZoneRange }` and have
  both call sites use it.
- `DomainModels.Zones` exposes named `z1…z5` fields only (no subscript) —
  `Profile.swift:36–48`.

## Test harness

- `TodayFeatureSceneStalenessTests.swift` — `test_sceneActive_dayRollover_reOrchestrates_hitsCheckInGate`
  pins rollover→gate with `$0.calendar = .europeSofia`, `$0.date = .constant(now)`,
  `sofiaInstant()` helper (`TodayTestHelpers.swift:39–47`), `-86400` for yesterday.
  NOT covered: child-state reset, non-`.ready` rollover, footer copy, hydrate seed
  after rollover, the chip.
- Component tests exist for check-in (`CheckInComponentTests`) and SafetyRest
  (`SafetyRestComponentTests`) — extend rather than new files where they fit.

## Useful Commands

```bash
xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme CoachKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'   # sim gate
make record-snapshots   # only if a new SafetyRest chip fixture is added
```

## Uncertainty

- Whether `.error` terminal states should re-orchestrate on ANY scene activation (not
  just rollover) — out of scope; 19.3 only closes the *rollover* gap via `contentDay`,
  same-day `.error` behavior unchanged (Retry is the affordance).
- Whether `readiness` reset matters visually (it is `ifLet`-scoped under `.ready`
  content that unmounts anyway) — reset kept for state hygiene; costs one line.
