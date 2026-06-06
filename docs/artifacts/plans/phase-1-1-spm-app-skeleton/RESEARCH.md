# Research: Phase 1.1 — SPM package & thin app target

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `docs/architecture/ARCHITECTURE.md` — the engineering blueprint. §2 (decisions log), §3 (layered
  architecture + dependency rule), §4 (the Swift package / target graph), §15 (concurrency), §18
  (third-party dependency inventory) are the binding references for this phase.
- `docs/artifacts/epics/01-foundation.md` — Phase 1.1 "What to build" / "Acceptance criteria" that
  this plan satisfies verbatim.
- `docs/artifacts/epics/EPICS.md` — epic status table; every later epic depends on Epic 01.
- `ios/` (project root) — currently contains only `docs/`. **No `Package.swift`, no `.xcodeproj`, not
  a git repository yet.** This phase creates all three.

## Architecture Facts

- **D1 — iOS 26+.** Single-user app; newest APIs, full native Observation. Platform line in
  `Package.swift` is `.iOS(.v26)`.
- **D2 — Swift 6.3, full strict concurrency.** Greenfield, no migration debt. TCA is Swift-6-ready.
- **D3 — Pure SPM package + thin app target.** One `Package.swift` (working name `CoachKit`) holds
  every feature/service as a library target; a minimal `.xcodeproj` app target just launches
  `AppFeature`. Explicitly **"zero extra tooling"** → no XcodeGen, no Tuist; the `.xcodeproj` is
  created and committed.
- **§4.5 — `AppFeature` is the root feature target.** In later epics it owns the tab bar, the
  onboarding switch, global 401 routing, and app-open orchestration. In 1.1 it is only a placeholder
  so the package builds and the app has something to render.
- **§3 dependency rule** — the `.xcodeproj` app target is the *composition root*; it is the only place
  that wires concrete/live values. For 1.1 it simply constructs `AppView(store:)`.
- **Strict-concurrency-by-default fact (critical for "no warnings"):** with a
  `swift-tools-version: 6.0+` manifest, SPM defaults each target's Swift **language mode to v6**, which
  enables *complete* strict-concurrency checking. The old `-strict-concurrency=complete` build flag and
  the `StrictConcurrency` upcoming-feature apply to the **Swift 5** language mode and are **not** needed
  here. Adding them is redundant; relying on the tools-version default is the clean path. **This plan
  nonetheless sets `swiftSettings: [.swiftLanguageMode(.v6)]` explicitly** — it is equivalent to the
  default but self-documents the intent and satisfies the epic's literal "strict-concurrency build
  settings" wording (validation round-1 #7).
- **`swift build` validates the macOS host, not iOS — which is exactly why the manifest needs a
  `.macOS` platform.** `swift build` / `swift test` compile the package for the host toolchain (Swift 6
  mode), so the package-level "no warnings" guarantee is a host check. TCA's products require
  macOS 13+, so a `platforms: [.iOS(.v26)]`-only manifest **fails to compile on the host** — the
  manifest therefore declares `[.iOS(.v26), .macOS(.v14)]` (the `.macOS` line governs only host
  build/test; the shipped app target stays iOS-only). The **iOS-target** build — and its own
  no-warnings check — happens via the xcodeproj build in TASK-003 (validation round-1 #3/#8, round-2
  #12, both verified on Xcode 26.4 / Swift 6.3).
- **§18 dependencies** — the only dependency required in 1.1 is
  `pointfreeco/swift-composable-architecture` (TCA), which transitively bundles swift-dependencies,
  CasePaths, and IdentifiedCollections. SharingGRDB / GRDB / snapshot-testing / swift-tagged arrive in
  later phases/epics, not here.

## Constraints

- No product behaviour — purely structural (epic Overview). The reducer/view are placeholders.
- No test target in this phase (the TestStore + snapshot harness is Phase 1.2). Verification is a
  clean `swift build` + a simulator launch only.
- The `.xcodeproj` must contain **only** the app entry point; `AppFeature` and all future code live in
  the package (acceptance criterion).
- All `AppFeature` symbols the app target touches (`AppFeature`, `AppFeature.State`, `AppView`, inits)
  must be `public` — they cross the package/app-target boundary.

## Useful Commands

```bash
# Toolchain / SDK / simulator sanity (run before building)
xcodebuild -version
xcodebuild -showsdks | grep -i ios
xcrun simctl list devices available | grep -i "iPhone"

# Package build under strict concurrency (no warnings expected)
swift build

# Resolve the local package reference from the xcodeproj
xcodebuild -resolvePackageDependencies -project CoachApp.xcodeproj -scheme CoachApp

# App build + launch on an iOS 26 simulator — prefer the `ios-build` skill, which
# auto-detects scheme + destination and avoids provisioning-profile errors.
```

## Uncertainty

- **Exact latest TCA version** — resolved to the latest stable (≥ 1.17) at implementation time and
  pinned in `Package.resolved`; not pinned to an exact patch in the manifest.
- **Whether Xcode 26 / an iOS 26 simulator is installed on the build machine** — checked at the start
  of TASK-002/003 via the commands above; if absent, the build acceptance criteria cannot be met and
  the implementer must install the toolchain first.
- **Generated vs checked-in Info.plist** — resolved to generated (`GENERATE_INFOPLIST_FILE = YES`) to
  keep the app target thin; revisit only if a later epic needs Info.plist keys (e.g. HealthKit usage
  descriptions in Epic 03).

## References

- ARCHITECTURE.md §2 (D1, D2, D3, D24), §3, §4, §15, §18.
- Epic 01 — Foundation & tooling, Phase 1.1.
- isowords (pointfreeco) — the reference pure-SPM-package + thin-app-target layout this mirrors.
