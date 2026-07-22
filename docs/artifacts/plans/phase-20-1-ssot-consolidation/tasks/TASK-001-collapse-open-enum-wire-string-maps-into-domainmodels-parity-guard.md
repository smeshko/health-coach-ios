# TASK-001: Collapse the open-enum wire-string maps into DomainModels + parity guard

Depends on: None
Suggested commit: `refactor(models): collapse open-enum wire-string maps to a single DomainModels owner`

## Goal

Each of `Flag`/`SafetyReason`/`PenaltyFactor` carries exactly one wire-string map, in
`DomainModels`, that both the `Codable` codec and `WireDomainMapping` route through —
and a parity test that fails if decode and encode ever disagree for a known case
(DECISIONS D1/D2).

## Files

- `Sources/Models/DomainModels/Sources/Flag.swift` — add `public init(wireString:)`
  (lookup in a `static let` dictionary derived from `knownCases`, `.unknown(raw)`
  fallback), make `wireString` `public` (stays the exhaustive switch), add
  `public static let knownCases: [Flag]` (all 12 non-unknown cases). `init(from:)`
  becomes `self.init(wireString: raw)`; drop the now-unneeded
  `swiftlint:disable cyclomatic_complexity`. Fix the header (:4–5): the mapping's
  owner is **this file** (ARCHITECTURE §5), UX labels stay in `DesignSystem`.
- `Sources/Models/DomainModels/Sources/SafetyReason.swift`,
  `Sources/Models/DomainModels/Sources/PenaltyFactor.swift` — same treatment (6 and
  5 known cases).
- `Sources/Models/WireDomainMapping/Sources/EnumMapping.swift` — **delete**.
- `Sources/Models/WireDomainMapping/Sources/BriefMapping.swift` — :19
  `PenaltyFactor(wireString: $0.factor)`; :64/:78
  `dto.flags.map(Flag.init(wireString:))`; :87
  `dto.reasons.map(SafetyReason.init(wireString:))`.
- `Sources/Models/DomainModels/Tests/WireStringParityTests.swift` — **new** (see
  Acceptance; Swift Testing, `import Foundation` for JSON coding).
- `Sources/Models/WireDomainMapping/Tests/EnumMappingTests.swift` — **delete** (its
  spot-checks are a strict subset of the parity tests; the closed-enum NOTE it carries
  is preserved by `DecodeRoundTripTests`, which it itself cites).

## Acceptance

- [ ] Exactly one string↔case pair list exists per enum (`wireString`'s switch); grep
  for `"needs_green_knee"` etc. finds one Swift source occurrence outside tests.
- [ ] `WireStringParityTests`, per enum: (1) `Self(wireString: c.wireString) == c` for
  every `knownCases` member — a case present in encode but missing in decode fails
  here; (2) JSON `Codable` round-trip for every known case; (3) wire strings pairwise
  distinct (`Set(knownCases.map(\.wireString)).count == knownCases.count`);
  (4) `.unknown("never_seen_xyz")` survives verbatim through `init(wireString:)` and
  `Codable`.
- [ ] Existing `CodableTests` (incl. `.unknown("quality_day")` → `.qualityDay`
  normalization) and `BriefMappingTests` pass unchanged.
- [ ] `EnumMapping.swift` and `EnumMappingTests.swift` no longer exist; nothing else
  references `EnumMapping` (grep clean).

Evidence: `swift test` output for DomainModels + WireDomainMapping test targets.

## Steps

### RED
- [ ] Write `WireStringParityTests` against the not-yet-existing `knownCases`/
  `init(wireString:)` API — compile failure is the red state; temporarily stub
  `knownCases` with one case omitted to watch assertion (1) actually fail, then fill.

### GREEN
- [ ] Add the API to the three enums; delegate `Codable`; derive the decode dictionary
  from `knownCases`.
- [ ] Delete `EnumMapping.swift`, rewire `BriefMapping`, delete `EnumMappingTests`.

### REFACTOR
- [ ] One comment block per enum binding the trio ("add a case → wireString switch
  (compiler-enforced) + knownCases (parity-tested)"); header doc corrections in all
  three files.

## Notes

- `knownCases` is `public` so the test target (plain `import DomainModels` style used
  by `CodableTests`) can iterate it — if the target uses `@testable`, internal is fine;
  match whichever the existing tests do.
- Keep the dictionary a `static let` (one-time build); `Dictionary(uniqueKeysWithValues:)`
  traps on duplicates — acceptable, and the parity test's distinctness check catches it
  first in CI.
- Behavior is intentionally bit-identical: same strings, same `.unknown` semantics,
  same D2-of-11.2 normalization. This commit moves code and adds tests, nothing else.
