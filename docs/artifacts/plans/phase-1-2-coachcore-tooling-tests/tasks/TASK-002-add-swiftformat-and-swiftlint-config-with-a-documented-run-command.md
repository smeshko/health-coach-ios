# TASK-002: Add SwiftFormat and SwiftLint config with a documented run command

Depends on: TASK-001
Suggested commit: `chore(tooling): add SwiftFormat + SwiftLint config and Makefile`

## Goal

Add `.swiftformat` + `.swiftlint.yml` config and a documented run command (`make format` / `make
lint`) so the codebase is linted/formatted from day one (ARCHITECTURE D24).

## Files

- `.swiftformat` (new) — SwiftFormat rules + Swift version line; exclude `.build`, `DerivedData`.
- `.swiftlint.yml` (new) — SwiftLint rule set; `included:` `Sources`/`Tests`, `excluded:` `.build`,
  `DerivedData`, `App` template assets as needed.
- `Makefile` (new) — `format` (`swiftformat .`) and `lint` (`swiftlint lint --strict`) targets.
- `README.md` (new or updated) — tooling install (`brew install swiftformat swiftlint`), the resolved
  tool versions, and how to run `make format` / `make lint`.
- `.git/hooks/pre-commit` (optional, documented) — runs `make lint` (and/or `make format`) before a
  commit; provide the script + opt-in install note (hooks aren't version-controlled by default).

## Acceptance

- [ ] `make lint` runs and reports **no violations** against the current `Sources/` + `Tests/`.
- [ ] `make format` is idempotent — running it leaves no diff on already-formatted sources.
- [ ] Config files are at the repo root and exclude build output directories.
- [ ] The README documents install, run command, and the pinned tool versions.

## Steps

- [ ] `brew install swiftformat swiftlint` (record the resolved versions for the README).
- [ ] Add `.swiftformat` with a conservative rule set + the project's Swift version.
- [ ] Add `.swiftlint.yml` with a conservative rule set; scope `included`/`excluded` paths.
- [ ] Add the `Makefile` with `format` and `lint` targets.
- [ ] Run `make format` then `make lint`; fix any violations in the existing 1.1 + 1.2 sources until
      both are clean.
- [ ] Document install + commands + versions in the README; add the optional pre-commit hook + its
      install note.

## Notes

- Keep the initial rule set **conservative** so it doesn't churn the small existing codebase; tighten
  later. `make format` must converge (no oscillation) and `make lint` must pass `--strict`.
- Do **not** wire linting into an Xcode build phase — the canonical build is SPM (`swift build` /
  `swift test`), so a build phase wouldn't run there and would slow Xcode builds (see DECISIONS.md §2).
- CI is deferred (D24); the `Makefile` targets are written so they drop into CI unchanged later.
