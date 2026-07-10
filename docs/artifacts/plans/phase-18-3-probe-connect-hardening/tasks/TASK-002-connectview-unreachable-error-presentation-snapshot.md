# TASK-002: ConnectView: unreachable error presentation + snapshot

Depends on: TASK-001
Suggested commit: `feat(onboarding): render server-unreachable state on Connect`

## Goal

The user can tell "my token is wrong" from "the server can't be reached" on the Connect
screen.

## Files

- `Sources/DesignSystem/Sources/Labels/DisplayLabel.swift` — the copy lives at the D19
  presentation boundary, NOT inline in the feature (validation round-1 #4): add an
  `ErrorDisplay.serverUnreachable` case (label e.g. "Can't reach the server — check your
  connection and server address"); `DisplayLabelTests` distinctness convention gains the
  case. (No gallery ripple — `LabelsGalleryPage` renders only `.upstreamTimeout`.)
- `Sources/Features/OnboardingFeature/Sources/ConnectView.swift` —
  - error row + field tint key off BOTH error cases: `.invalid` keeps its exact current
    copy/tint (existing snapshots must not change); `.unreachable` renders the same row
    structure with `ErrorDisplay.serverUnreachable.label` and the same negative tint.
  - Add an `.unreachable` preview alongside the existing `.invalid` one.
- `Sources/Features/OnboardingFeature/Tests/` snapshot target — one new snapshot CASE for
  the `.unreachable` state — a light+dark PNG PAIR, matching every existing case
  (validation round-1 #3) — recorded on the pinned sim (`make record-snapshots`, review
  the diff; only the new pair may appear).

## Acceptance

- [ ] `.invalid` renders byte-identical to before (existing OnboardingFeature snapshots
  pass un-re-recorded).
- [ ] `.unreachable` renders `ErrorDisplay.serverUnreachable.label` (new snapshot case
  green on the pinned sim).
- [ ] `make test-snapshots` green; `make lint` green; `DisplayLabelTests` distinctness
  updated.

Evidence: snapshot run transcript + `git status` showing exactly the new light+dark pair.

## Steps

### RED
- [ ] Add the `.unreachable` snapshot case — fails (no reference PNG / no render arm).

### GREEN
- [ ] Render arm + record the reference on the pinned sim.

### REFACTOR
- [ ] Preview for the new state; doc comment updated (three states story).

## Notes

Do NOT re-record unrelated snapshots (memory: snapshot-rerecord-workflow — record mode
reports recorded snapshots as failures; the `-` make prefix hides the expected non-zero
exit). If `record-snapshots` regenerates more than the new light+dark pair, discard the
others (`git checkout --`) and investigate before committing. View style: no computed
`some View` properties (memory: no-view-building-properties) — inline or extract a struct.
