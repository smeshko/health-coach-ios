# TASK-006: CoachWidgets extension target: pbxproj, App Group entitlements, embed

Depends on: TASK-004,TASK-005
Suggested commit: `feat(widgets): CoachWidgets extension target + shared App Group`

## Goal

Hand-author the `CoachWidgets` WidgetKit extension target in `project.pbxproj` (existing CA-id style),
give app + extension the shared App Group, embed the appex in the app, and prove both targets compile for
the canonical sim — with the extension linking ONLY WidgetsUI + WidgetSnapshotClientLive + DomainModels.

## Files

- `CoachWidgets/CoachWidgetsBundle.swift` — new (the ONLY source in the extension target, DECISIONS D4):
  `import SwiftUI`, `import WidgetKit`, `import WidgetsUI`; `@main struct CoachWidgetsBundle:
  WidgetBundle { var body: some Widget { SkeletonWidget() } }`. Later phases append one line per widget
  here — nothing else in the target ever changes.
- `CoachWidgets/Info.plist` — new: `NSExtension` dict with `NSExtensionPointIdentifier =
  com.apple.widgetkit-extension` (hand keys merged via `GENERATE_INFOPLIST_FILE = YES`, the App/Info.plist
  mechanism).
- `CoachWidgets/CoachWidgets.entitlements` — new: `com.apple.security.application-groups` =
  `[group.com.smeshko.CoachApp]`.
- `App/CoachApp.entitlements` — edit: add the same `com.apple.security.application-groups` array
  alongside the existing HealthKit keys.
- `Package.swift` — edit: add `.library(name: "DomainModels", targets: ["DomainModels"])` (the extension
  links it read-only per the epic's architecture note) and amend the products comment ("app target" →
  "app + CoachWidgets extension targets" one-liner).
- `CoachApp.xcodeproj/project.pbxproj` — edit, new objects in the free `…02xx` CA-suffix range
  (RESEARCH.md); every existing `DEVELOPMENT_TEAM = GR9SJM3FZP` line preserved:
  - `PBXFileReference`: `CoachWidgets.appex` (`wrapper.app-extension`, `BUILT_PRODUCTS_DIR`),
    `CoachWidgetsBundle.swift`, `Info.plist`, `CoachWidgets.entitlements`; new `PBXGroup` "CoachWidgets"
    (path `CoachWidgets`) under the main group; appex ref added to the Products group.
  - `PBXSourcesBuildPhase` (CoachWidgetsBundle.swift), `PBXFrameworksBuildPhase` (three
    `PBXBuildFile`s from `XCSwiftPackageProductDependency`s: **WidgetsUI, WidgetSnapshotClientLive,
    DomainModels — and NOTHING else**; this exact list is the epic's no-GRDB/no-APIClient criterion),
    empty `PBXResourcesBuildPhase`.
  - `PBXNativeTarget` "CoachWidgets": `productType = "com.apple.product-type.app-extension"`, the three
    `packageProductDependencies`, its own `XCConfigurationList`.
  - 2× `XCBuildConfiguration` (Debug/Release) mirroring the CoachApp target-config keys where relevant:
    `CODE_SIGN_ENTITLEMENTS = CoachWidgets/CoachWidgets.entitlements`, `CODE_SIGN_STYLE = Automatic`,
    `DEVELOPMENT_TEAM = GR9SJM3FZP`, `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_FILE =
    CoachWidgets/Info.plist`, `INFOPLIST_KEY_CFBundleDisplayName = CoachWidgets`,
    `PRODUCT_BUNDLE_IDENTIFIER = com.smeshko.CoachApp.CoachWidgets`, `PRODUCT_NAME = "$(TARGET_NAME)"`,
    `SKIP_INSTALL = YES`, `SWIFT_VERSION = 6.0`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`,
    `TARGETED_DEVICE_FAMILY = "1,2"`, `CURRENT_PROJECT_VERSION`/`MARKETING_VERSION` matching the app,
    `LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks",
    "@executable_path/../../Frameworks")`. No `Base.xcconfig` (the API seam is app-only).
  - Embed: `PBXContainerItemProxy` + `PBXTargetDependency` on CoachApp; new `PBXCopyFilesBuildPhase`
    "Embed Foundation Extensions" (`dstSubfolderSpec = 13`, `dstPath = ""`) with the appex
    `PBXBuildFile` (`ATTRIBUTES = (RemoveHeadersOnCopy)`); phase appended to CoachApp's `buildPhases`,
    dependency to its `dependencies`; CoachWidgets added to the project's `targets` list (+ a
    `TargetAttributes` entry mirroring the existing one).

## Acceptance

- [ ] `xcodebuild -project CoachApp.xcodeproj -scheme CoachApp -destination 'platform=iOS
      Simulator,name=iPhone 17 Pro,OS=26.0' build` succeeds and the build log shows CoachWidgets
      compiled + embedded (compile-only — no sim test run).
- [ ] `grep -c "DEVELOPMENT_TEAM = GR9SJM3FZP" project.pbxproj` == 4 (2× app + 2× extension).
- [ ] The CoachWidgets `packageProductDependencies` block lists exactly WidgetsUI,
      WidgetSnapshotClientLive, DomainModels (the epic's dependency-audit criterion).
- [ ] Both entitlements files carry `group.com.smeshko.CoachApp`.
- [ ] `swift build`, `swift test`, `make lint` still green (Package.swift product addition is inert for
      the host).

Evidence: xcodebuild BUILD SUCCEEDED output (with the CoachWidgets target lines); the grep count; the
pbxproj diff.

## Steps

This is hand-authored project surgery — checklist style inside the impl frame:

### RED
- [ ] Run the sim-destination build BEFORE the edit to capture a known-good baseline log.

### GREEN
- [ ] Write the three `CoachWidgets/` files; edit both entitlements; add the Package.swift product; author
      the pbxproj objects in the order listed in Files (references → phases → target → configs → embed).

### REFACTOR
- [ ] Re-run the sim-destination build; fix until green; diff-review the pbxproj hunk-by-hunk against the
      Files spec (ids unique, every referenced id defined, team lines intact).

## Notes

- If the appex product type fights the toolchain (widget templates on some Xcode versions emit the
  ExtensionKit variant), fall back to `com.apple.product-type.extensionkit-extension` +
  `EXAppExtensionAttributes` (`EXExtensionPointIdentifier = com.apple.widgetkit-extension`) and embed via
  `dstSubfolderSpec = 16` ("Extensions") — pick whichever the CURRENT Xcode's own widget template
  generates; verify by scaffolding a throwaway template project OUTSIDE this repo if unsure. Record the
  choice in the commit body.
- Simulator builds don't validate App Group provisioning; the real-device check (automatic signing
  registering the group for GR9SJM3FZP) is owner-side — listed in TASK-007's unverified items.
- The widget must appear in the sim's widget gallery once the app is installed — that runtime proof is
  the final task's verify-on-sim step, not this task's compile gate.
