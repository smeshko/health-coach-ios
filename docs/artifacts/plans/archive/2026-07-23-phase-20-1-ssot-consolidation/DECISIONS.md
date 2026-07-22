# Decisions — Phase 20.1 SSOT consolidation

## D1 — The wire-string maps' single owner is `DomainModels`; `EnumMapping` is deleted, not delegated

The dependency graph decides this, not taste: `WireDomainMapping` imports
`DomainModels` and the reverse is forbidden (ARCHITECTURE §5), and the `Codable`
codec — which *must* embed a map — already lives in `DomainModels` (Phase 11.2). So
the map can only be single if it lives with the enum. Each open enum gets:

```swift
public init(wireString: String)      // non-failing, .unknown(raw) fallback
public var wireString: String        // exhaustive switch — compiler-checked on new cases
public static let knownCases: [Self] // every case except .unknown
```

`Codable` delegates (`init(from:)` → `init(wireString:)`; `encode` → `wireString`).

`EnumMapping` is **deleted** rather than kept as a delegating shim: a shim is a second
public-ish surface whose only future is to drift again, and its four `BriefMapping`
call sites read at least as well as `Flag.init(wireString:)`. Its header comment's
claim to ownership — and the mirror-image stale claim in `Flag.swift` :4–5 ("mapping
lives in `WireDomainMapping`, never here") — both get corrected to name `DomainModels`
as the owner, which also re-aligns the code with ARCHITECTURE §5's existing text.

## D2 — Decode derives from `knownCases`; the parity test iterates `knownCases`; residual risk accepted and stated

`init(wireString:)` looks up a `static let` dictionary built as
`Dictionary(uniqueKeysWithValues: knownCases.map { ($0.wireString, $0) })`. This makes
decode and encode *structurally* incapable of diverging: both sides read the one
exhaustive `wireString` switch. The parity test (`WireStringParityTests`, in
`DomainModels/Tests` next to the owner) then pins, per enum:

- every `knownCases` member survives `init(wireString: c.wireString) == c` (no
  `.unknown` leak),
- full JSON `Codable` round-trip for every known case,
- wire strings are pairwise distinct (`Set` count — also, a duplicate would trap the
  `uniqueKeysWithValues` precondition at first decode),
- `.unknown("never_seen")` passthrough and the D2-of-11.2 normalization
  (`.unknown("quality_day")` → `.qualityDay`) keep behaving.

**Residual risk, accepted:** Swift cannot enumerate cases of an enum with an
associated value, so a case added to the enum + `wireString` but *omitted from
`knownCases`* is invisible to the parity test — the new wire string would decode
`.unknown`. Why this is acceptable: (a) the omission is now a loud functional failure
(the case is undecodable *everywhere*, caught the moment a fixture or real brief uses
it — `BriefMappingTests` fixtures are the second net), versus today's silent
one-copy-updated drift across two modules; (b) all three declarations are adjacent in
one file with a comment binding them. Alternatives rejected: a manual `CaseIterable`
conformance whose `allCases` excludes `.unknown` (lies about the type's contract for
zero added enforcement — it's the same hand-maintained list under a standard name);
restructuring as `case known(Known); case unknown(String)` with a `CaseIterable`
inner enum (full compiler enforcement, but breaks every construction/match site across
the app for a 12-case enum — not worth the blast radius in this codebase).

## D3 — The meter consumes the backend band; thresholds survive only as marker-axis geometry

`SegmentedBar.readiness(score:)` becomes `readiness(score:band:)`. The highlight (which
band is active/bold, where the marker glows) comes from the passed domain
`ReadinessBand` — the value the backend computed and `Readiness` already carries
non-optionally. Client-side banding computation drops to **zero** places; the view
consumes the domain value, satisfying the phase AC in its strongest form.

Rejected alternative: adding `ReadinessBand(score:)` to `DomainModels` and keeping the
score-only API. That keeps a client-side derivation alive (merely relocated) and —
worse — leaves the Today screen reading the band from two sources at once: the band
word from `readiness.band`, the meter highlight from a score re-derivation. One
screen, one band source is the point of this phase.

What stays in `SegmentedBar` (private extension on the *domain* `ReadinessBand`):
width fractions (0.5/0.25/0.25), label alignment, and the score ranges
0–50/50–75/75–100 used **only** to place the marker on the meter's axis — that is
chart geometry (the axis scale), not banding. Marker progress is clamped to 0…1 so an
inconsistent payload (score 80, band amber) pins the marker at the band edge instead
of escaping the segment; the highlight trusts the band. Labels/colors come from the
D19 conformances (`band.label`/`band.color`) — the private duplicates are deleted.
The meter keeps an explicit local order `[.red, .amber, .green]`: domain `allCases`
is `[green, amber, red]` and reordering the domain declaration for a chart would
ripple through every other `allCases` consumer.

## D4 — Label unification lands on the D19 owner's "Ease Off"

The two spellings ("Ease off" meter-private vs "Ease Off" in `ClosedEnumLabels`)
render on the same Today screen today; unifying necessarily changes one surface. The
D19 owner wins: "Ease Off" is title-case-consistent with every sibling label ("Easy
Run", "Active Recovery", …) and is what the more prominent band word already shows.
Consequence: readiness-meter snapshots diff by one capital letter (flagged in
PLAN Risks; ship stage re-records). Changing the owner to sentence case instead would
diff the band word on the same snapshots — no cheaper, and it would break D19's
convention.

## D5 — `DayTypePatternEntry.weekday` is the one normalization point

The wire contract keeps `suggestedDay` a free string (openapi), so the domain struct
keeps the verbatim `String` (no mapping-layer coercion, no silent data rewrite). The
domain type gains the *interpretation*:

```swift
public var weekday: Weekday? { Weekday(rawValue: suggestedDay.lowercased()) }
```

`CarbCyclingPattern` matches `entry.weekday == weekday` — enum equality, no string
comparison in the view. Any future consumer of the pattern gets the same reading for
free, which is the SSOT spirit of the phase. Lowercasing is the whole fix: the
`Weekday` raw values are the wire's lowercase `mon…sun` keys, and the observed failure
mode is case mismatch. Full-name aliases ("Tuesday") stay out of scope — that would be
inventing contract the backend doesn't have; an unrecognized string still falls to the
rest-day cut, now only for *actually* unknown values.
