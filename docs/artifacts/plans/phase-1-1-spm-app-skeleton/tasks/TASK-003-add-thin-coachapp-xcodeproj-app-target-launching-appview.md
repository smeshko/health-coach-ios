# TASK-003: Add thin CoachApp .xcodeproj app target launching AppView

Depends on: TASK-002
Suggested commit: `feat(foundation): add thin CoachApp app target`

## Goal

Add a thin `CoachApp.xcodeproj` app target whose `@main` `App` builds
`AppView(store: Store(initialState:) { AppFeature() })` and that depends on the local `CoachKit`
package, so the placeholder renders on the iOS 26 simulator.

## Files

- `CoachApp.xcodeproj/` (new) — the app project, referencing the root package as a *local* package and
  linking the `AppFeature` product.
- `CoachApp.xcodeproj/xcshareddata/xcschemes/CoachApp.xcscheme` (new) — the **shared** scheme (so it is
  committed and `xcodebuild -scheme CoachApp` / the `ios-build` skill work from a clean clone).
- `CoachApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (new) — the xcodeproj's
  resolved package state; **committed** (this is what the app build resolves against).
- `App/CoachApp.swift` (new) — the `@main` `App` (composition root); no logic beyond building
  `AppView(store:)`.
- `App/Assets.xcassets/` (new) — app icon / accent color asset catalog (from the template).
- `Package.swift` — unchanged (the xcodeproj references it; the package does not depend on the app).

## Acceptance

- [ ] The `CoachApp` scheme builds and launches on an iOS 26 simulator **with no warnings** and shows
      the placeholder `AppView` (run icon + "Coach").
- [ ] `xcodebuild -resolvePackageDependencies -project CoachApp.xcodeproj -scheme CoachApp` succeeds
      (local package resolves).
- [ ] The scheme is **shared and tracked**: `CoachApp.xcodeproj/xcshareddata/xcschemes/CoachApp.xcscheme`
      exists and is committed (so a clean clone can `xcodebuild -scheme CoachApp`).
- [ ] The xcodeproj's `project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is committed.
- [ ] `App/CoachApp.swift` contains only the `@main` `App` + `WindowGroup { AppView(store:) }` — no
      reducers, models, or other logic.
- [ ] No source files for `AppFeature` (or any future code) live inside the xcodeproj / `App/` beyond
      the entry point — all of it stays in `Sources/` (package).

## Steps

### RED
- [ ] Before the xcodeproj exists there is no app to launch — that is the starting "red". Verification
      is the **simulator build + launch**, preferably via the `ios-build` skill (auto-detects scheme +
      iOS 26 destination, avoids provisioning-profile errors).
- [ ] Confirm an iOS 26 simulator is available: `xcrun simctl list devices available | grep -i iphone`.

### GREEN
- [ ] Create the project from Xcode's **App** template (SwiftUI lifecycle), product name `CoachApp`,
      then strip it down per [`../DECISIONS.md`](../DECISIONS.md):
  - Delete the generated `ContentView.swift`.
  - Move/author the entry point as `App/CoachApp.swift`:
    ```swift
    import AppFeature
    import ComposableArchitecture
    import SwiftUI

    @main
    struct CoachApp: App {
      var body: some Scene {
        WindowGroup {
          AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
        }
      }
    }
    ```
  - *Add Local Package…* pointing at the package directory (the repo root) and add the `AppFeature`
    library to the target's **Frameworks, Libraries, and Embedded Content**.
  - Set `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `GENERATE_INFOPLIST_FILE = YES` (no checked-in
    `Info.plist`). **Keep** the template-generated `PRODUCT_BUNDLE_IDENTIFIER` and `PRODUCT_NAME` — they
    are load-bearing for install/launch; the strip-down only removes `ContentView.swift` and unused
    settings. (No App Icon, min-macOS, or explicit app-target Swift version is required to launch.)
  - **Mark the scheme Shared**: Product ▸ Scheme ▸ Manage Schemes… ▸ tick **Shared** for `CoachApp`, so
    `CoachApp.xcscheme` is written under `xcshareddata/xcschemes/` and gets committed.
- [ ] Build & launch on the iOS 26 simulator; confirm the placeholder renders **with no build warnings**.
- [ ] Commit the xcodeproj **including** the shared scheme and
      `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

### REFACTOR
- [ ] Verify the xcodeproj is minimal: only the `CoachApp` target, the local-package reference, the
      `App/` entry sources, and the asset catalog. No test target yet (1.2).
- [ ] Confirm `swift build` (package) still passes independently of the app build.

## Notes

- **Local package reference**, not a remote URL — the xcodeproj points at the same-directory
  `Package.swift`; this is the composition root wiring described in ARCHITECTURE §3. **Verify the
  reference is relative**, not absolute: the pbxproj `XCLocalSwiftPackageReference`'s `relativePath`
  should be `.` (or empty), so the project resolves on any machine / clean clone.
- If Xcode is unavailable on the build machine, the DECISIONS.md fallback (hand-authored minimal
  `project.pbxproj`) applies, but the Xcode-template path is strongly preferred.
- Keep the app target free of any business logic — adding logic here would violate the "xcodeproj
  contains only the app entry point" acceptance criterion and ARCHITECTURE D3/§3.
