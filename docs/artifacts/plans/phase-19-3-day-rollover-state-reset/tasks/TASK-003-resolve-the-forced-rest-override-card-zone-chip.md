# TASK-003: Resolve the forced-REST override card zone chip

Depends on: None
Suggested commit: `fix(today): resolve the forced-REST override card zone chip from loaded zones`

## Goal

The forced-REST override card's zone chip is resolved instead of hardcoded `nil`: an
`active_recovery` override with `zoneTarget` renders its bpm range from the loaded
zones, `rest`/`mobility` overrides (no `zoneTarget`) keep rendering no chip, and the
"reconciled when that lands" placeholder comment is gone.

## Files

- `Sources/Features/TodayFeature/Sources/Session/SessionFeature.swift` (or a small new
  in-module file, e.g. `Zones+Range.swift`) — extract the exhaustive `zone → zones.zN`
  switch into an internal `extension Zones { func range(for zone: Zone) -> ZoneRange }`
  (DECISIONS D4); `SessionFeature.State.zoneRange(for:)` delegates to it (public
  behavior identical — pinned by existing `SessionFeatureTests`).
- `Sources/Features/TodayFeature/Sources/TodayReadyContent.swift` — the
  `.forcedRest(gate, override)` branch: replace `zoneRange: nil` (and the stale
  "when that lands" comment) with a call to a **pure, testable helper** (validation
  round-1 #6 — view-body derivation is not observable by tests): e.g. a static
  `overrideZoneRange(override: SessionBlock, zones: Zones?) -> ZoneRange?` living
  beside `TodaySessionMode` (the existing pure derivation home), implemented as
  `override.zoneTarget.flatMap { zones?.range(for: $0) }`.
- `Sources/Features/TodayFeature/Tests/TodayFeatureTests/SafetyRestComponentTests.swift`
  (the pure test home) — cases over the helper: tripped gate + `active_recovery`
  override with `zoneTarget: .z1` + zones → `zones.z1` (exact bpm); `zones == nil` →
  nil; `zoneTarget == nil` (`rest`/`mobility`) → nil. **Fixture note (round-1 #6): no
  existing fixture has a triggered gate + activeRecovery + zoneTarget** — the tripped
  fixtures are `card: rest` without `zoneTarget`, and `daily_brief_red`
  (activeRecovery + z1) has `triggered: false` — so hand-roll the brief in the test:
  `SafetyGate(triggered: true, overrideTo: .activeRecovery)` +
  `SessionBlock(card: .activeRecovery, zoneTarget: .z1, …)`.

## Acceptance

- [ ] Pure helper: `active_recovery` + zones → `zones.z1` (exact bpm values asserted);
  `zones == nil` → `nil` (degrade, no crash); `rest`/`mobility` → `nil` (unchanged);
  the forcedRest branch calls the helper (grep — no inline derivation in the view
  body).
- [ ] `SessionFeature.State.zoneRange(for:)` behavior unchanged (existing tests green,
  now through the shared extension).
- [ ] No `zoneRange: nil` hardcode nor the "when that lands" comment remain in
  `TodayReadyContent.swift`.
- [ ] Existing SafetyRest/Today snapshot PNGs byte-identical (their fixtures pass
  nil-zone shapes); if a chip-resolved snapshot is added, it is recorded via
  `make record-snapshots` on the pinned device and reviewed.

Evidence: TodayFeature test-suite output for the derivation cases; grep showing the
hardcode/comment gone; snapshot suite green without re-records (or the deliberate new
PNG noted).

## Steps

### RED
- [ ] Add the derivation tests — the `active_recovery`+zones case fails against the
  hardcoded `nil`.

### GREEN
- [ ] Extract the `Zones.range(for:)` extension, delegate `zoneRange(for:)`, wire the
  forcedRest branch.

### REFACTOR
- [ ] One-line comment in the forcedRest branch stating the derivation rule
  (`zoneTarget` drives; zones nil ⇒ silent degrade — mirrors the normal session card).

## Notes

- `SafetyRestView` stays render-only (§3 — "the view never resolves zones itself");
  resolution happens in the parent content view exactly like the normal-session branch.
- Zones freshness is 19.2's concern (per-sync refetch) — this task only consumes
  `state.zones`.
