# TASK-003: URL-scheme deep links: coachapp:// routes into AppFeature (Today / Weekly / check-in)

Depends on: None
Suggested commit: `feat(app): coachapp:// URL scheme + deep-link routing (Today / Weekly / check-in)`

## Goal

Register the `coachapp` URL scheme and route `coachapp://today`, `coachapp://weekly`, and
`coachapp://checkin` through the AppFeature reducer, with the URL vocabulary in CoachCore so later
phases' widgets can use the same constants in `widgetURL` — all reducer-/parser-unit-tested.

## Files

- `Sources/Core/CoachCore/Sources/CoachDeepLink.swift` — new (DECISIONS D5):
  - `public enum CoachDeepLink: Equatable, Sendable, CaseIterable { case today, weekly, checkIn }`.
  - `public static let scheme = "coachapp"`; per-case `public var url: URL` (`coachapp://today`,
    `coachapp://weekly`, `coachapp://checkin` — host-based, lowercase).
  - `public init?(url: URL)` — case-insensitive scheme + host match, nil for anything else. Pure
    Foundation, no dependencies.
- `Sources/Core/CoachCore/Tests/CoachDeepLinkTests.swift` — new (host, Swift Testing, existing
  CoachCoreTests target — path already covers the whole `Tests/` dir): each case round-trips
  (`CoachDeepLink(url: $0.url) == $0` via `allCases`), wrong scheme nil, unknown host nil, uppercase
  variants parse.
- `Sources/Features/AppFeature/Sources/AppFeature.swift` — edit:
  - New action `case deepLink(URL)` (public surface, sits beside `notificationOpened`).
  - Reducer arm: parse with `CoachDeepLink(url:)`; unparseable → `log.notice` on `.app`, `.none`.
    Guard `case var .main(main) = state.route` (dropped while onboarding — the `notificationOpened`
    precedent, AppFeature.swift:204-219). `.today` → `main.selectedTab = .today`; `.weekly` →
    `main.selectedTab = .weekly`; `.checkIn` → `main.selectedTab = .today` (the check-in flow IS the
    Today tab's `BriefViewState.checkInRequired` gate — an unlogged day surfaces the check-in card
    itself; the distinct case is kept so 21.5 can specialise without a new URL contract). Re-embed via
    `state.route = .main(main)`; one `log.info` route line on `.app`.
- `Sources/Features/AppFeature/Sources/AppFeature+SessionRouting.swift` — edit: **MANDATORY** — the new
  `.deepLink` case makes the SECOND, separate exhaustive switch in `reduceSessionRouting` non-exhaustive
  (its final arm is an explicit case list `._restoreSession, ._tokenChecked, .notificationOpened,
  .onboarding, .main:` with NO `default:` — line ~44). Add `.deepLink` to that same catch-all arm
  (routed in `AppFeature.body`, never here — the exact treatment `notificationOpened` already gets there).
  Omitting this edit is a compile error (validation round-1 #1).
- `Sources/Features/AppFeature/Sources/AppView.swift` — edit: `.onOpenURL { store.send(.deepLink($0)) }`
  on the single outer `ZStack` (beside the existing `.task`, line 46 — same never-re-mounting container
  reasoning).
- `App/Info.plist` — edit: `CFBundleURLTypes` array with one entry — `CFBundleURLName` =
  `com.smeshko.CoachApp.deeplink`, `CFBundleURLSchemes` = `[coachapp]` — with a short comment block in
  the existing house style (the `UILaunchScreen`/`APIBaseURL` merge mechanism).
- `Sources/Features/AppFeature/Tests/AppFeatureTests/DeepLinkTests.swift` — new (host, Swift Testing,
  existing AppFeatureTests target): TestStore cases —
  - `coachapp://weekly` from `.main` on `.today` → `selectedTab == .weekly`;
  - `coachapp://today` from `.main` on `.weekly` → `.today`;
  - `coachapp://checkin` → `.today`;
  - any route while `.onboarding` → no state change;
  - unknown URL (`coachapp://nope`, `https://example.com`) → no state change.

## Acceptance

- [ ] Parser round-trips all three canonical URLs and rejects foreign scheme/host (CoachCoreTests green).
- [ ] Reducer routes the three deep links, drops them while onboarding, no-ops on unknown URLs
      (AppFeatureTests green).
- [ ] `CFBundleURLTypes` present in App/Info.plist with the single `coachapp` scheme.
- [ ] `swift build`, `swift test`, `make lint` all green.

Evidence: `swift test` output for the two new suites; the Info.plist diff.

## Steps

### RED
- [ ] Add `CoachDeepLinkTests.swift` + `DeepLinkTests.swift` (imports: Testing, Foundation,
      ComposableArchitecture for the TestStore file; `test_` prefixes).

### GREEN
- [ ] Implement `CoachDeepLink`, the body reducer arm, the `.deepLink` entry in `reduceSessionRouting`'s
      catch-all arm, `.onOpenURL`, and the Info.plist entry.

### REFACTOR
- [ ] Confirm the reducer arm reads like `notificationOpened` (guard shape, logging, re-embed);
      `make lint`.

## Notes

- Widgets in 21.2–21.5 use `.widgetURL(CoachDeepLink.today.url)` etc. — never re-typed string literals;
  that is the entire reason the vocabulary lives in CoachCore (WidgetsUI can't import AppFeature).
- No `onOpenURL` sim run is required here — reducer-level tests are this task's gate; end-to-end URL
  opening is covered by the final task's verify-on-sim pass (implementation-time).
- The `.checkIn` arm intentionally does NOT force `todayRoot` orchestration — `onAppOpen`/scene-active
  hooks already own hydration; the route only picks the tab.
