# Adversarial Validation — Round 1

**Run:** 2026-07-24 12:15 UTC
**Plan:** widget-infrastructure
**Status at start:** draft
**Reviewer:** Codex (`codex-cli 0.144.5`, adversarial-review, working-tree scope) — partial: Codex read
every plan file and the referenced source (BriefRepositoryLive policies, DomainModels, AppFeature +
AppFeature+SessionRouting, MainTabs, Package.swift, project.pbxproj, entitlements/Info.plist/Makefile,
CoachCore ISOWeek/Calendar) and emitted one grounded interim finding message before the foreground run
hit the 10-minute cap and was terminated (SIGTERM) mid-ranking. The interim message is pasted verbatim
below. Its two flagged issues were then independently re-grounded against current source by the validator
(the switch-exhaustiveness break and the merge stale/lost-update paths both confirmed by reading the
files), and the validator completed the remaining coherence sweep (extension transitive-dep closure,
liveValue resolution, acceptance-criterion coverage) inline as the Codex-unavailable fallback prescribes.

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

```json
{"verdict":"needs-attention","summary":"Current-source checks have already disproved several load-bearing assumptions: one task would not compile because it misses an existing exhaustive action switch, and the snapshot mutation design has both stale-day and lost-update paths. I'm finishing the extension/provisioning and final-validation checks before ranking the blockers.","findings":[],"next_steps":[]}
```

(Foreground run terminated at the 10-minute cap immediately after this message; job log
`…/state/phase-21-1-*/jobs/review-mryw6s6g-acgasr.log` shows the reads it completed. Findings below are
the validator's grounding of Codex's two named issues plus the completed coherence sweep.)

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | TASK-003 adds `case deepLink(URL)` to `AppFeature.Action` but only edits the body reducer switch; the SECOND exhaustive switch in `AppFeature+SessionRouting.swift` (`reduceSessionRouting`, catch-all arm `._restoreSession, ._tokenChecked, .notificationOpened, .onboarding, .main`, no `default`) goes non-exhaustive → compile error. | high | apply | Confirmed by reading the file: no `default`, explicit case list. TASK-003 must also add `.deepLink` to that arm. | TASK-003 |
| 2 | TASK-002 merge preserves `selectedSession` unconditionally (`existing?.daily?.selectedSession`); on a new Sofia day the prior day's selection carries into the new daily section (stale), and acceptance case #2 freezes that behavior for 21.2 to inherit. | med | apply | The merge semantics are frozen in 21.1; preserve `selectedSession` only when the existing daily is the SAME Sofia day as the new brief, else nil. | TASK-002 |
| 3 | `WidgetSnapshotStore` (a `struct`) does read→merge→atomic-write with no serialization. `Data.write(.atomic)` prevents torn READS but not lost UPDATES when writers interleave — and 21.1 freezes this design for later phases that add sibling section writers (weekly/selected/check-in), each read-modify-writing the same file. | med | apply | Real robustness gap in a frozen-now design; route the live client's read/merge/write through a single actor so concurrent section writers can't lose each other's updates. | PLAN.md:Risks, TASK-002 |
| 4 | TASK-007 final-validation checklist does not explicitly enumerate PLAN.md acceptance criteria 5 (full-schema encode/decode+merge unit test), 6 (staleness helpers host-tested), 8 (`DEVELOPMENT_TEAM` == 4 across configs); they are only implicitly under the swift-test gate / TASK-006 grep. | low | apply | The final-validation task's contract is that every acceptance criterion has named evidence; add explicit lines so none is ticked on "looks right." | TASK-007 |

### Rejected / not-findings (validator coherence sweep, re-grounded against source)

- **liveValue dynamic resolution from the extension process** (D4/RESEARCH) — SOUND. Verified against the
  LogClient split: interface provides `TestDependencyKey`/`DependencyValues` accessor, Live provides
  `DependencyKey: liveValue`; a process linking `…Live` resolves the live value with no
  `prepareDependencies`. No change.
- **Extension transitive-dep closure clean of Database/GRDB/APIClient** (acceptance #4) — VERIFIED.
  WidgetsUI → DesignSystem → {DomainModels, CoachCore, HealthKitClient(interface)→WireModels}; grep of
  those targets shows no `import Database/APIClient/GRDB`. RESEARCH D4 is accurate. No change.
- **WidgetKit on the macOS host** — `#if canImport(WidgetKit)` guard-always is sufficient; no change.
- **`.checkIn` routes to the Today tab** — deliberate DECISIONS D5 (the Today gate IS the check-in flow);
  distinct case kept for 21.5. Consistent, no change.
- **pbxproj DEVELOPMENT_TEAM currently == 2, LogClientLive foursome pattern real** — verified; TASK-005/006
  ids and embed-phase shape match current source. No change.
