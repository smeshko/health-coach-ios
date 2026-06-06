# Coach App (iOS)

Native iOS app built as a single Swift package (`CoachKit`) plus a thin `CoachApp.xcodeproj` app
target — the [isowords](https://github.com/pointfreeco/isowords) model: pure SPM, zero project
generators. iOS 26+, Swift 6.3 (full strict concurrency), TCA.

## Layout

- `Package.swift` — the `CoachKit` package (all features/services land here as targets).
- `Sources/AppFeature/` — the root TCA feature + `AppView`.
- `Sources/CoachCore/` — foundation utilities: the Europe/Sofia calendar/date dependency,
  ISO-week helpers, and the `Tagged` ID convention.
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

# iOS snapshot tests — AppFeatureSnapshotTests (SwiftUI image snapshots are UIKit-only and
# cannot run under `swift test`); run on an iOS 26 simulator:
xcodebuild test -scheme CoachApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Snapshot references are recorded on the iOS 26 simulator (light + dark, single reference device).
To re-record after an intentional view change, wrap the assertion in
`withSnapshotTesting(record: .all) { … }`, run once on the simulator, then revert and commit the
new references.

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
