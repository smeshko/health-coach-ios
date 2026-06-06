# How to create & place the thin app target

Date: 2026-06-06

## Options Considered

1. **Xcode App-template strip-down** — create a new app target from Xcode's "App" template, then
   delete the generated `ContentView`/boilerplate, add the root `Package.swift` as a *local* package
   dependency, and link the `AppFeature` product. The `@main` `App` becomes a few lines building
   `AppView(store:)`.
2. **Hand-authored `project.pbxproj`** — write the `.xcodeproj` bundle's `project.pbxproj` by hand
   (or from a minimal known-good template), wiring the local package reference and product link
   manually.
3. **Project generator (XcodeGen / Tuist)** — declare the app target in a `project.yml` /
   `Project.swift` and generate the `.xcodeproj`.

## Dependencies

- ARCHITECTURE.md **D3**: "Pure SPM package + thin app target … The isowords model — matches the
  brief exactly, **zero extra tooling**." This rules generators out.
- The app target must be the *composition root* only and contain no logic beyond launching
  `AppView(store:)` (epic acceptance criterion + §3).
- The `.xcodeproj` is committed to git (it is the app's build definition); whatever produces it, the
  result is what ships.

## Selected Option

**Option 1 — Xcode App-template strip-down.**

## Rationale

- Honours D3's "zero extra tooling": no XcodeGen/Tuist dependency enters the repo, and the committed
  `.xcodeproj` is a normal Xcode project any contributor can open.
- Far lower risk than hand-authoring `project.pbxproj`: the template produces a guaranteed-valid
  project (correct object graph, build settings, scheme), and the only manual steps are well-trodden
  Xcode UI actions — *Add Local Package…* pointing at the package directory, then adding the
  `AppFeature` library to *Frameworks, Libraries, and Embedded Content*.
- Keeps the target genuinely thin: delete the template's `ContentView.swift`, set
  `GENERATE_INFOPLIST_FILE = YES` (no checked-in `Info.plist`), and reduce `@main` to the
  `WindowGroup { AppView(store:) }` body.

## Rejected Options

- **Hand-authored `project.pbxproj`** — rejected: the `pbxproj` format is verbose and brittle; a
  subtle mistake in the package product reference or build phases produces opaque failures, and it
  buys nothing over the template once D3 forbids generators. (Acceptable only as a fallback if Xcode
  is unavailable on the build machine.)
- **XcodeGen / Tuist** — rejected: directly violates D3's "zero extra tooling"; adds a generator
  dependency and a generate step to every build for a single trivial app target.
