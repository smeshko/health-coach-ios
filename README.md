# Coach App (iOS)

Native iOS app built as a single Swift package (`CoachKit`) plus a thin `CoachApp.xcodeproj` app
target — the [isowords](https://github.com/pointfreeco/isowords) model: pure SPM, zero project
generators. iOS 26+, Swift 6.3 (full strict concurrency), TCA.

## Layout

The whole package source tree lives under `Sources/`, organized into one folder per layer. Every
target declares an explicit `path:` in `Package.swift` — no target relies on the default
`Sources/<TargetName>` convention — and each module's tests are co-located under its own `Tests/`
subfolder (one test target → files directly under `Tests/`; more than one → `Tests/<TestTargetName>/`).

- `Package.swift` — the `CoachKit` package (all features/services land here as targets).
- `Sources/Repositories/<Name>/{Interface,Live,Tests}` — repository modules (the get-or-generate seams).
- `Sources/Clients/<Name>/{Interface,Live,Tests}` — data-source clients (API, Database, HealthKit, …).
- `Sources/Features/<Name>/{Sources,Tests}` — TCA features; `Sources/Features/AppFeature/Sources/` is
  the root feature + `AppView`.
- `Sources/Models/<Name>/{Sources,Tests}` — the wire/domain/persistence model + sample-data modules.
- `Sources/Core/CoachCore/Sources/` — foundation utilities: the Europe/Sofia calendar/date dependency,
  ISO-week helpers, and the `Tagged` ID convention (`Sources/Core/CoachTestSupport/` holds the shared
  snapshot test helper).
- `Sources/DesignSystem/{Sources,Tests}` — color/typography/spacing tokens + the enum→label boundary.
- `App/` — the `@main` composition root (`CoachApp.swift`); launches `AppView(store:)`.
- `CoachApp.xcodeproj` — the thin app target (references the local package).

## Build & run

```bash
swift build                 # compile the package (macOS host)
make build                  # same, via the Makefile

# App on the iOS 26 simulator: open CoachApp.xcodeproj and run the CoachApp scheme,
# or `xcodebuild build -scheme CoachApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
```

## Tests

Two distinct run paths (not interchangeable):

```bash
# Host logic tests — CoachCoreTests + AppFeatureTests (exhaustive TestStore):
swift test            # or: make test

# iOS snapshot tests — DesignSystemSnapshotTests + AppFeatureSnapshotTests (SwiftUI image
# snapshots are UIKit-only and cannot run under `swift test`):
make test-snapshots
```

`make test-snapshots` always runs on the **single canonical simulator — `iPhone 17 Pro, OS 26.0`**
(pinned via `SNAPSHOT_DEVICE` in the `Makefile`). This matters: snapshot references are recorded on
that exact device, and running on any other simulator produces sub-pixel rendering diffs that fail at
the default exact precision. Run snapshots through the make target, never a hand-rolled `-destination`,
so the device never drifts.

The `CoachKit-Package` scheme (committed under `.swiftpm/xcode/package.xcworkspace/xcshareddata/`)
also runs the logic test targets, so `xcodebuild test … -scheme CoachKit-Package` (without
`-only-testing`) runs the whole suite on the simulator.

Snapshot references are recorded on the canonical simulator above (light + dark, single reference
device — geometry pinned to `coachReferenceDevice` in `Sources/CoachTestSupport/SnapshotConvention.swift`).
To re-record after an intentional view change, run `make record-snapshots` (same pinned device), then
review the regenerated PNGs with `git diff` before committing. Record mode exits non-zero by design.

## Tooling — SwiftFormat & SwiftLint

Install (Homebrew):

```bash
brew install swiftformat swiftlint
```

Pinned versions (the versions this config was validated against):

| Tool | Version |
|------|---------|
| SwiftFormat | 0.57.2 |
| SwiftLint | 0.59.1 |

Run:

```bash
make format   # swiftformat .            (formats all Swift sources in place; idempotent)
make lint     # swiftlint lint --strict  (any warning fails)
```

Config lives at the repo root: `.swiftformat` and `.swiftlint.yml`.

### Optional pre-commit hook

A pre-commit hook that runs `make lint` is provided in `.githooks/`. Opt in with:

```bash
git config core.hooksPath .githooks
```

Bypass for a single commit with `git commit --no-verify`.

> CI is intentionally deferred until later (ARCHITECTURE D24); the `make` targets are written to drop
> straight into CI unchanged.
