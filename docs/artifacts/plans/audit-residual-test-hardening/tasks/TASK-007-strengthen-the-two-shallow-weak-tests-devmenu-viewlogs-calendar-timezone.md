# TASK-007: Strengthen the two shallow WEAK tests (DevMenu viewLogs, Calendar timeZone)

Depends on: None
Suggested commit: `test: strengthen DevMenu viewLogs + Calendar timeZone WEAK tests`

## Goal

Replace two shallow assertions (audit WEAK verdicts) with real-behavior checks: the
DevMenu log-viewer presentation should route a child action through the presented state;
the Sofia calendar pin should be asserted through a `\.timeZone` consumer, not by reading
back what the setter wrote.

## Files

- `Sources/Features/SettingsFeature/Tests/SettingsFeatureTests/DevMenuFeatureTests.swift`
  — `test_viewLogsTapped_presentsAndDismissesLogViewer` (`:136`): after presenting,
  drive one `LogViewer` child action through the presentation
  (`.logViewer(.presented(.onAppear))` → assert the child loads/anchors, e.g.
  `isLoading`/`referenceDate` or a `logsLoaded` receive via a stubbed `\.log`), proving
  the scoped child reducer is wired — not just the `@Presents` setter + `ifLet` dismiss.
- `Sources/Core/CoachCore/Tests/CalendarTests.swift` —
  `testUseEuropeSofiaPinsCalendarAndTimeZone` (`:93`): assert the pin through a
  `\.timeZone`-consuming computation (e.g. a value whose result differs between
  Europe/Sofia and UTC) rather than reading `timeZone.identifier` back; keep the existing
  calendar-identity assert if useful but add the behavioral one.

## Acceptance

- [ ] The DevMenu test exercises a routed child action through the presented
      `LogViewerFeature` (not only present/dismiss plumbing) and asserts a resulting child
      state change.
- [ ] The Calendar test asserts Europe/Sofia is load-bearing via a `\.timeZone` consumer
      whose output would change under UTC — not by restating the setter.
- [ ] Both modules' suites green; host + sim suites green.

## Steps

### RED
- [ ] Rewrite the two assertions to their behavioral form (the DevMenu one needs a stubbed
      `\.log.readRecent`; the Calendar one needs a UTC-vs-Sofia distinguishing value).

### GREEN
- [ ] n/a — strengthening existing passing tests; adjust only if the stronger assertion
      reveals a real gap.

### REFACTOR
- [ ] Run both suites; host + sim suites.

## Notes

`test_perTabStacks_startEmpty` (the third WEAK) is intentionally NOT touched — its
strengthening is blocked on Epics 9/10 adding pushable Week/You destinations (the test's
own comment says so). Out of scope per PLAN.md.
