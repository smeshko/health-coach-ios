# TASK-004: Composition-root wiring: AppConfig, Info.plist key, API_BASE_URL build setting, explicit apiClient

Depends on: TASK-003
Suggested commit: `feat(app): inject API base URL at the composition root (closes CR-1)`

## Goal

The app target owns URL injection end-to-end: build setting → Info.plist → `AppConfig` →
explicit `$0.apiClient` in `prepareDependencies`, with first-launch seeding fed the same fact.

## Files

- `CoachApp.xcodeproj/project.pbxproj` — two kinds of edit (validation round-1 #1):
  - add User-Defined `API_BASE_URL = "";` to BOTH app-target build-config blocks (Debug ~line
    307, Release ~line 337 — the blocks carrying `INFOPLIST_FILE = App/Info.plist`). Empty by
    design: the owner sets the real hostname locally (never committed — RUNBOOK posture);
  - register `App/AppConfig.swift` for compilation — the project uses ordinary (non-
    filesystem-synchronized) groups, so a new file needs FOUR records, mirroring
    `AppDelegate.swift`'s: a `PBXFileReference`, a `PBXBuildFile`, a child entry in the App
    `PBXGroup`, and a line in the app target's `PBXSourcesBuildPhase`. Use fresh unique ids in
    the existing `CA…` id style.
- `App/Info.plist` — add `<key>APIBaseURL</key><string>$(API_BASE_URL)</string>` alongside the
  existing `UILaunchScreen` dict, with a short comment tying it to CR-1/Phase 18.1.
- `App/AppConfig.swift` (new) — thin: `enum AppConfig { static let apiBaseURL: URL? =
  APIBaseURL.resolve(bundle: .main) }` (`import Foundation` + `import APIClientLive` — the
  latter allowed only here, composition root; Foundation is NOT transitively re-exported,
  round-3 #4).
- `App/CoachApp.swift` —
  - `DevSettings.seedFirstLaunchDefault(liveBackendConfigured: AppConfig.apiBaseURL != nil)`;
  - inside `prepareDependencies`:
    `$0.apiClient = AppConfig.apiBaseURL.map { .live(baseURL: $0) } ?? .unconfigured`;
  - when the unconfigured arm is taken, emit one `.app`-category log line
    (`"API base URL unconfigured — set API_BASE_URL; APIClient will throw on use"`) so a
    mis-substituted production URL is diagnosable from the on-device log viewer
    (round-3 #1, slim arm — full error presentation is deferred, see PLAN.md);
  - refresh the surrounding comments (the auto-resolve comment for APIClient is now wrong —
    it is explicitly injected; Database/HealthKitClient/TokenClient/DevSettings still
    auto-resolve).

## Acceptance

- [ ] App target builds for the simulator with `API_BASE_URL` empty (unconfigured path) — via
  ios-build skill / `xcodebuild build`.
- [ ] App target builds with `API_BASE_URL=https://coach.example.com` override
  (`xcodebuild ... API_BASE_URL=https://coach.example.com build`) — configured path compiles
  and the plist carries the substituted value (verify in the built product's Info.plist).
- [ ] The same override build ALSO passes with `-configuration Release` (simulator
  destination), and the Release product's Info.plist carries the substituted URL — Debug
  substitution is not Release evidence (round-3 #3).
- [ ] **Runtime demonstration on the simulator** (validation round-1 #3): launch the override
  build (`API_BASE_URL=https://coach.example.com`), flip live mode if needed, trigger a
  probe/sync, and capture the request log showing the client targeting
  `coach.example.com` (a failing TLS/DNS response is fine — the evidence is the HOST in the
  `.http` log line, proving the composition root injected the configured URL end-to-end).
- [ ] `swift test` + `make lint` stay green (no package-level change in this task beyond
  comments).

Evidence: two xcodebuild invocations' success output + `plutil -p` of the built app's
Info.plist showing the substituted URL + a `.http` log excerpt from the simulator run showing
the configured host (verify-on-sim skill).

## Steps

### RED
- [ ] n/a for pbxproj/plist; treat the two xcodebuild builds as the executable check. Package
  tests from TASK-001..003 already pin resolver/seeding behaviour.

### GREEN
- [ ] Make the four edits; run both builds; inspect the built Info.plist.

### REFACTOR
- [ ] Comment pass: CoachApp composition-root comment block accurately lists what is explicit
  vs auto-resolved.

## Notes

pbxproj build-setting edit is additive one line per block — keep placement near the INFOPLIST
keys to minimize diff noise; do NOT touch `MARKETING_VERSION`/bundle id lines. The simulator
dev loop is unaffected: empty setting → resolver's DEBUG+simulator fallback → localhost:8000,
same as today. The sim runtime demonstration above is the land gate for the seam; the
*physical-device* probe/sync against the owner's real HTTPS host remains the epic-level
Validation step (owner action — the pipeline has no phone/server access). Record it as
CI-pending in the PR body and leave the corresponding epic acceptance box unticked until the
owner demonstrates it.
