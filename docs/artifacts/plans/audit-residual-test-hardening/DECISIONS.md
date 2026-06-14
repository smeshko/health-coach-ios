# Decisions — Audit residual test hardening

## D1 — LogViewer double-refresh is fixed, not pinned-as-is

Date: 2026-06-13

### Options Considered

1. **Fix**: add `.cancellable(id: CancelID.reload, cancelInFlight: true)` to the
   `onAppear`/`refreshTapped` reload effect, then test that only the latest reload lands.
2. **Pin-only**: write a characterization test documenting the current out-of-order
   behavior, change no production code.

### Dependencies

`LogViewerFeature.swift:80-86` returns an uncancelled `.run` that calls
`log.readRecent()`. Two rapid reloads (the toolbar Refresh, or `onAppear` racing a
Refresh) run two reads; whichever `logsLoaded` arrives last wins, so a stale snapshot can
overwrite a newer one. The reducer also re-anchors `referenceDate` per load, so an
out-of-order land mis-anchors the relative date filters too. DEBUG-only, but reachable by
a fast double-tap.

### Selected Option

Option 1 (Fix). The user chose "fix reachable, pin the rest"; this is the one reachable
bug in the residual set. The fix is one line + a `CancelID` enum, matching the pattern
`_appWillAppear` already uses (`.cancellable(cancelInFlight: true)`).

### Rejected Options

- Option 2 (Pin-only) — pinning a known out-of-order bug as "documented behavior" is
  worse than the one-line guard. Rejected.

## D2 — The concurrent-sync() race is characterized, not serialized

Date: 2026-06-13

### Options Considered

1. **Characterize + document**: a deterministic test pins what two concurrent
   `runSync()` calls do today; a code/DECISIONS note records that the only caller
   serializes, so no guard ships.
2. **Serialize**: add an in-flight guard (an actor or a `@Dependency` flag) so a second
   `runSync()` awaits or no-ops while one is in flight, preventing watermark regression.
3. **Out of scope**: leave it entirely (the original Epic 11 deferral).

### Dependencies

`runSync()` (`SyncRepository+Live.swift:26-85`) is a stateless free function: read
watermark → capture `readInstant` → POST → write watermark. Two concurrent calls can move
the watermark anchor backwards and double-attach the strength test. **But** the only
caller, `TodayFeature`'s orchestration, runs the sync under `.cancellable(cancelInFlight:
true)`, so a new invocation cancels the prior — concurrent `sync()` is not reachable
in-app. The app is single-user.

### Selected Option

Option 1 (Characterize + document). The user chose "fix reachable, pin the rest"; the
race is not reachable, so a pinning test plus a recorded rationale closes the audit item
honestly without shipping a guard for a path no caller exercises.

### Rationale

A characterization test is cheap, documents the read→write watermark invariant, and
gives a future second caller a tripwire. Shipping serialization now is blast radius on
the sync path for an unreachable race in a single-user app.

### Rejected Options

- Option 2 (Serialize) — premature; if a second caller is ever added, the pinned test
  flags the behavior to revisit.
- Option 3 (Out of scope) — zero coverage is what made it a lingering audit gap.
