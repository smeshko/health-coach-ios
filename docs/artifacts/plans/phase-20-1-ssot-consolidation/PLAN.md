# Plan: SSOT consolidation

Status: planned
Branch: refactor/phase-20-1-ssot-consolidation
Risk: medium
Epic: 20 — Make it adjustable (audit wave 3) ([epic](../../epics/20-adjustable-architecture.md))
Phase: 20.1 — SSOT consolidation
Linear: none
Created: 2026-07-22

## Goal

Every duplicated domain rule the Architecture lens flagged collapses to a single owner
with a guard against silent re-divergence: the open-enum wire-string maps live only in
`DomainModels` (with a parity test), the readiness-band highlight consumes the domain
`ReadinessBand` instead of re-deriving it from hardcoded 50/75 thresholds, and a
case-mismatched `suggestedDay` no longer silently renders as a rest day.

## Scope

- `Sources/Models/DomainModels/Sources/Flag.swift`, `SafetyReason.swift`,
  `PenaltyFactor.swift` — each open enum gains `init(wireString:)`, `wireString`, and
  `knownCases`; the `Codable` codec delegates to them (one map per enum, total).
- `Sources/Models/WireDomainMapping/Sources/EnumMapping.swift` — deleted; its four
  `BriefMapping.swift` call sites call the `DomainModels` inits directly.
- `Sources/Models/DomainModels/Tests/` — new `WireStringParityTests.swift` (the parity
  guard); `Sources/Models/WireDomainMapping/Tests/EnumMappingTests.swift` deleted.
- `Sources/DesignSystem/Sources/Primitives/SegmentedBar.swift` — the private
  score-thresholded `ReadinessBand` enum is deleted; `.readiness(score:band:)` consumes
  the domain band, reusing the D19 label/color conformances; only marker-axis geometry
  stays local.
- `Sources/Features/TodayFeature/Sources/Readiness/ReadinessComponentView.swift` and
  `Sources/Features/DesignSystemGallery/Sources/Pages/PrimitiveComponentPages.swift` —
  callers pass the band.
- `Sources/Models/DomainModels/Sources/Nutrition.swift` — `DayTypePatternEntry` gains a
  case-insensitive `weekday: Weekday?`;
  `Sources/DesignSystem/Sources/Composites/CarbCyclingPattern.swift` matches through it.
- `Sources/Models/DomainModels/Tests/ValueTypeTests.swift` — weekday-normalization cases.

## Out of Scope

- Phase 20.2 (silent-failure surfacing) and 20.3 (weekly ISO-week rollover).
- Any change to the wire contract, persisted format, or backend banding thresholds —
  this phase moves code, it does not change what any value means.
- New test *targets*. DesignSystem already has a host-runnable pure-logic target
  (`DesignSystemTests`, `@testable import DesignSystem`, Package.swift ≈:956 — it pins
  `PainSeverity`/`effortBand`/`RangeFormatter`/`CoachMotion`); the D3 marker clamp gets
  a case there (TASK-002), so no new target is needed.
- Running snapshot tests / re-recording PNGs (ship stage owns the simulator). Expected
  diffs are flagged in Risks and must be carried into the final report.
- The closed enums (`Card`, `Zone`, …) — already single-declaration since Phase 11.3.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing findings:

- The flag map exists **three** times (`Flag.swift` decode :32–46 + encode :54–70,
  `EnumMapping.swift` :14–30) and the reason/factor maps twice each — all pairs
  currently in sync, nothing enforcing it. `Flag.swift`'s header (:4–5) still claims
  "the raw wire string ↔ case mapping lives in `WireDomainMapping`, never here" —
  stale since Phase 11.2 gave `DomainModels` the codec (ARCHITECTURE §5).
- Dependency direction forces the owner: `WireDomainMapping` imports `DomainModels`,
  never the reverse — so the single map can only live in `DomainModels`.
- `SegmentedBar.swift` :205–256 re-derives banding (`score >= 75 / >= 50`, :209) in a
  private `ReadinessBand` that duplicates the labels and colors `ClosedEnumLabels.swift`
  :34–50 already owns per D19 — and has drifted: the meter axis renders "Ease off"
  while the Today screen renders the domain `band.label` "Ease Off" *directly above it*
  (`ReadinessComponentView.swift` :61–66).
- The domain band is backend-computed and non-optional on `Readiness` — the one caller
  with real data already holds it; only the gallery invents scores.
- Domain `ReadinessBand.allCases` is `[green, amber, red]` — the meter's left-to-right
  is red→amber→green, so the meter must keep an explicit local order, not `allCases`.
- `CarbCyclingPattern.swift` :44 matches `$0.suggestedDay == weekday.rawValue` —
  exact-case string equality against a documented **free** wire string
  (`Nutrition.swift` :72–75), so `"Tue"` falls through to the rest-day cut silently.
- Snapshot fixtures: carb-cycling pages use lowercase days (byte-identical after the
  fix); every readiness-meter snapshot renders all three axis labels, so the
  "Ease off"→"Ease Off" unification diffs them (Risks).

## Decisions

See [DECISIONS.md](./DECISIONS.md) — D1 owner = `DomainModels`, `EnumMapping` deleted
not delegated; D2 decode map derived from `knownCases` + parity-test guard (and its
residual risk); D3 meter consumes the backend band, thresholds survive only as marker
axis geometry; D4 label unification on the D19 owner's "Ease Off"; D5
`DayTypePatternEntry.weekday` as the one normalization point.

## Risks

- **Snapshot diffs (expected, flagged not run):** the readiness meter's center axis
  label changes "Ease off" → "Ease Off" in `BarsSnapshotTests` (readiness section),
  `ReadinessSnapshotTests`, and any `TodayViewSnapshotTests` case showing the meter.
  This is the fix correcting a real drift (the two spellings render on the same Today
  screen today), not accidental churn. Carb-cycling snapshots stay byte-identical
  (lowercase fixtures). Ship stage re-records on the pinned sim.
- **Band/score disagreement:** trusting the backend band means a `(score: 80, band:
  .amber)` payload highlights amber and pins the marker at the band edge (progress
  clamped 0…1). Previously the client silently re-banded to green — the new behavior
  is the correct one (backend is the banding SSOT) but is a behavior change on
  inconsistent payloads. Never observed in fixtures or production briefs.
- **Parity-guard residual:** a case added to an enum + `wireString` but omitted from
  `knownCases` decodes to `.unknown` and the parity test cannot see it (Swift can't
  enumerate cases with associated values). Mitigated: the decode dictionary is *derived*
  from `knownCases`, so the omission is a loud functional failure (the new wire string
  never decodes) caught by the fixture-driven `BriefMappingTests`/integration paths,
  and all three declarations sit adjacent in one file. Recorded in D2.
- **API churn:** `SegmentedBar.readiness(score:)` → `(score:band:)` breaks the two
  call sites — both updated in the same commit; no other callers exist (grep-verified).
- **Lint:** deleting the `cyclomatic_complexity` disables must not resurface warnings —
  the dictionary-lookup init has no branching; `make lint` gates it.

## Acceptance Criteria

- [ ] Each of `Flag`/`SafetyReason`/`PenaltyFactor` has exactly one wire-string map
  (in `DomainModels`); `EnumMapping.swift` and `EnumMappingTests.swift` are gone;
  `BriefMapping` and the `Codable` codecs route through the same `init(wireString:)`/
  `wireString` pair; stale "mapping lives in WireDomainMapping" doc headers corrected.
- [ ] `WireStringParityTests` fails if a known case round-trips to `.unknown`, if
  decode(encode(case)) ≠ case for any `knownCases` member, or if two cases claim one
  wire string — for all three enums.
- [ ] `SegmentedBar` contains no score-threshold banding: the private `ReadinessBand`
  enum is deleted, the active band is the passed domain `ReadinessBand`, labels/colors
  come from the D19 conformances, and 50/75 appear only as marker-axis score ranges in
  one private extension. Both callers pass a band; marker progress is clamped.
- [ ] The meter axis renders "Recover / Ease Off / Ready" — one spelling everywhere.
- [ ] `DayTypePatternEntry(suggestedDay: "Tue", …)` renders its bar on Tuesday (and
  `"TUE"` likewise); unknown strings still fall through to the rest-day cut; behavior
  pinned by `ValueTypeTests` weekday cases.
- [ ] `make lint` (swiftlint --strict) and `make test` (full host package suite) green
  from the worktree root; no snapshot run attempted; expected snapshot diffs enumerated
  in the final report for the ship stage.

## Tasks

Task state lives here. Update the checkboxes as work progresses.

- [x] TASK-001: Collapse the open-enum wire-string maps into DomainModels + parity guard
- [x] TASK-002: Route the readiness meter through the domain ReadinessBand
- [ ] TASK-003: Case-insensitive suggestedDay matching via DayTypePatternEntry.weekday
- [ ] TASK-004: Final Validation
