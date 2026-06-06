# TASK-001: Bootstrap git repository and Swift/Xcode .gitignore

Depends on: None
Suggested commit: `chore(foundation): init git repo and Swift/Xcode .gitignore`

## Goal

Make the `ios/` directory a git repository with a `.gitignore` that keeps Swift/Xcode build artifacts
out of version control, so every subsequent task can commit cleanly.

## Files

- `.gitignore` (new) — Swift Package Manager + Xcode ignore rules.
- `.git/` (new) — created by `git init`.

## Acceptance

- [ ] `git rev-parse --is-inside-work-tree` prints `true` from the `ios/` root.
- [ ] `.gitignore` exists and ignores at least: `.build/`, `/.swiftpm/`, `DerivedData/`,
      `**/xcuserdata/`, `*.xcuserstate`, and `.DS_Store`.
- [ ] `.gitignore` does **not** ignore `Package.resolved` or anything under `xcshareddata` (shared
      schemes + the xcodeproj's resolved package state must stay tracked).
- [ ] `git status` after a hypothetical build would not list build products (i.e. the ignore globs
      match SwiftPM/Xcode output paths).

## Steps

- [ ] `git init` at the `ios/` project root.
- [ ] Create `.gitignore` covering: `.build/`, **`/.swiftpm/`** (anchored to the top-level CLI scratch
      dir only — do **not** use a bare `.swiftpm/` that could over-match), `DerivedData/`, `build/`,
      `**/xcuserdata/`, `*.xcuserstate`, and `.DS_Store`. Do **not** ignore either `Package.resolved`
      (root or xcodeproj) and do **not** ignore `**/xcshareddata/**` (shared schemes + the xcodeproj's
      resolved package state live there — see Notes).
- [ ] Stage the existing `docs/` tree and `.gitignore` and make the initial commit.

## Notes

- **Keep both `Package.resolved` files tracked** (do not ignore them) so dependency versions are
  reproducible: the SPM package's `/Package.resolved` (root, created in TASK-002) **and** the
  xcodeproj's `CoachApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (created in
  TASK-003 — this is the file the app actually builds against for the local-package graph). The manifest
  pins TCA with `from:`; `Package.resolved` records the resolved patch.
- **Do not ignore `xcshareddata`.** The committed **shared scheme**
  (`CoachApp.xcodeproj/xcshareddata/xcschemes/CoachApp.xcscheme`, see TASK-003) and the xcodeproj's
  resolved package state both live under `xcshareddata`. Only per-user state under `xcuserdata`
  (and `.swiftpm` CLI scratch) is ignored.
- This task runs **before** `Package.swift` exists; that is intentional — the repo must exist so
  TASK-002 / TASK-003 produce real commits.
- A `.DS_Store` already exists under `docs/`; the ignore rule should cover it and it should not be
  committed.
