# TASK-002: Route the readiness meter through the domain ReadinessBand

Depends on: None
Suggested commit: `refactor(design-system): readiness meter consumes the domain ReadinessBand`

## Goal

The readiness meter's highlight is the backend-computed band, not a client
re-derivation: `SegmentedBar`'s private score-thresholded `ReadinessBand` enum is
deleted, `.readiness(score:band:)` takes the domain band, and labels/colors come from
the D19 conformances. 50/75 survive only as marker-axis geometry in one private
extension (DECISIONS D3/D4).

## Files

- `Sources/DesignSystem/Sources/Primitives/SegmentedBar.swift` —
  - `import DomainModels` (additive; the target already depends on it).
  - `static func readiness(score: Int, band: ReadinessBand) -> SegmentedBar` replaces
    `readiness(score:)` (:156). Active band = the parameter; segments/labels iterate a
    local `meterOrder: [ReadinessBand] = [.red, .amber, .green]` (domain `allCases` is
    green→amber→red — do NOT use it, and do NOT reorder the domain enum).
  - Delete the private `ReadinessBand` enum (:205–256). Keep a `private extension
    DomainModels.ReadinessBand` with only meter geometry: `meterFraction`
    (0.5/0.25/0.25), `meterAlignment` (leading/center/trailing), `axisRange`
    (0…50 / 50…75 / 75…100), `markerProgress(for score:)` — clamped to 0…1 after the
    range math so an inconsistent (score, band) pair pins the marker at the band edge.
  - Labels use `band.label` / colors `band.color` (from `ClosedEnumLabels` — "Recover"
    / "Ease Off" / "Ready"); `isActive: $0 == band`.
  - Update the shape's doc comment (:9–10) — it no longer derives the band.
- `Sources/Features/TodayFeature/Sources/Readiness/ReadinessComponentView.swift` :66 —
  `SegmentedBar.readiness(score: store.readiness.score, band: store.readiness.band)`.
- `Sources/Features/DesignSystemGallery/Sources/Pages/PrimitiveComponentPages.swift`
  :239–241 — explicit consistent pairs, e.g.
  `[(10, ReadinessBand.red), (60, .amber), (88, .green)]`, `ForEach(…, id: \.0)`.

## Acceptance

- [ ] No `score >= 75` / `score >= 50` (or any banding threshold comparison) exists in
  DesignSystem; the only 50/75 literals left are the `axisRange` bounds in the one
  private geometry extension.
- [ ] The private `ReadinessBand` enum and its duplicated label/color tables are gone;
  the meter's label text and colors are the D19 conformances' (meter axis now renders
  "Ease Off" — the deliberate D4 unification).
- [ ] Both call sites compile passing a band; no other caller exists (grep
  `readiness(score` clean).
- [ ] Marker fraction is clamped: an inconsistent pair like (80, .amber) cannot place
  the marker outside its segment (code-reviewable — see Notes on testability).
- [ ] Full host suite (`make test`) green; no snapshot run.

Evidence: `make lint` + `make test` output; grep transcript for the threshold check.

## Steps

### RED
- [ ] No host-runnable test target covers DesignSystem (snapshot-only, UIKit-gated) —
  the red state is the two callers failing to compile against the new signature.

### GREEN
- [ ] Rewrite the shape + geometry extension; delete the private enum; update both
  callers.

### REFACTOR
- [ ] Keep the geometry extension adjacent to the shape with a comment naming the
  boundary: banding is the backend's (domain `Readiness.band`); this extension owns
  only the axis scale and marker placement.

## Notes

- **Snapshot impact (flag, don't run):** every readiness-meter snapshot renders all
  three axis labels, so `BarsSnapshotTests` (readiness section), Today's
  `ReadinessSnapshotTests`, and meter-showing `TodayViewSnapshotTests` cases will diff
  by "Ease off" → "Ease Off". Carry this list into the final report for the ship
  stage's re-record. No other pixel should move: colors, fractions, alignments, marker
  math (for consistent pairs) are value-identical.
- Adding a host unit-test target for DesignSystem just to test `markerProgress`
  clamping is out of scope (PLAN Out of Scope); the clamp is one `min(max(…))`
  reviewed in code and exercised by the gallery snapshots at ship.
- `LabelsGalleryPage` iterates domain `allCases` — untouched by keeping `meterOrder`
  local.
