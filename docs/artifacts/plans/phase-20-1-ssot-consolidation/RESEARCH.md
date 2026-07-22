# Research — Phase 20.1 SSOT consolidation

All line numbers against `refactor/phase-20-1-ssot-consolidation` at plan time
(= `origin/staging`, a7593d6).

## 1. The triplicated flag map / duplicated open-enum maps

- `Sources/Models/DomainModels/Sources/Flag.swift`
  - :30–47 `init(from:)` — 12-case string switch, `.unknown(raw)` default, under a
    `swiftlint:disable cyclomatic_complexity`.
  - :54–70 `private var wireString` — the same 12 pairs, exhaustive switch (compiler
    checked), `.unknown(raw)` verbatim.
  - :4–5 header doc: "The raw wire string ↔ case mapping lives in `WireDomainMapping`,
    never here" — **stale**: Phase 11.2 moved `Codable` (and therefore a full map) into
    this file; ARCHITECTURE §5 now says `DomainModels` "Owns `Codable` … the three open
    enums keep a single-value raw-string codec with `.unknown` fallback".
- `Sources/Models/DomainModels/Sources/SafetyReason.swift` :18–29 decode + :36–46
  encode — 6 pairs, same shape. `PenaltyFactor.swift` :17–27 + :34–43 — 5 pairs.
- `Sources/Models/WireDomainMapping/Sources/EnumMapping.swift` — the third flag copy
  (:14–30) and second reason/factor copies (:32–42, :44–53). Header (:3–5) declares
  itself the raw-string → open-enum home; internal `enum EnumMapping`.
- Call sites of `EnumMapping` (all in
  `Sources/Models/WireDomainMapping/Sources/BriefMapping.swift`):
  - :19 `EnumMapping.penaltyFactor($0.factor)`
  - :64, :78 `dto.flags.map(EnumMapping.flag)`
  - :87 `dto.reasons.map(EnumMapping.safetyReason)`
- **Dependency direction:** `WireDomainMapping` imports `DomainModels`
  (EnumMapping.swift:1); ARCHITECTURE §5 states the reverse import stays forbidden.
  A single owner reachable from both the codec and the mapper can only be
  `DomainModels`.
- Existing tests:
  - `Sources/Models/DomainModels/Tests/CodableTests.swift` :45–70 — spot-checks a few
    known cases per enum through the codec, `.unknown` passthrough, and the D2
    case-colliding-unknown normalization (`.unknown("quality_day")` → `.qualityDay`).
    Not exhaustive over cases; keeps passing unchanged after the collapse.
  - `Sources/Models/WireDomainMapping/Tests/EnumMappingTests.swift` — spot-checks the
    `EnumMapping` copy (subset of cases). Dies with `EnumMapping`; its coverage is
    strictly subsumed by the new exhaustive parity tests.
  - `BriefMappingTests.swift` + `WireFixtures.swift`/`DomainFixtures.swift` exercise
    the wire→domain path end-to-end and stay as the fixture-level guard.

## 2. Readiness banding re-derivation

- `Sources/DesignSystem/Sources/Primitives/SegmentedBar.swift`
  - :156–174 `static func readiness(score:)` — builds segments/labels/marker from a
    **private** `ReadinessBand` (:205–256).
  - :209 the re-derivation: `if score >= 75 { .ready } else if score >= 50 { .easeOff }
    else { .recover }` — the hardcoded 50/75.
  - Private dupes of D19-owned presentation: colors :212–218
    (negative/warning/positive — identical to the domain conformance), labels :220–226
    (**"Ease off"** — diverged), plus genuinely meter-local geometry: width fractions
    0.5/0.25/0.25 (:228–233), label alignment (:235–241), score ranges 0–50/50–75/
    75–100 (:243–249), `progress(for:)` (:252–255, clamps the *score* 0…100 but the
    fraction itself can only exceed 0…1 if range and band disagree — impossible today
    because both derive from the same score).
- The domain SSOT:
  - `Sources/Models/DomainModels/Sources/ClosedEnums.swift` :40–42 —
    `public enum ReadinessBand: String … { case green, amber, red }`. **Declaration
    order is green→amber→red; the meter renders red→amber→green left-to-right**, so
    the meter needs an explicit local order, not `allCases`.
  - `Sources/Models/DomainModels/Sources/Readiness.swift` :4–15 — `band` is
    non-optional, backend-computed, alongside `score`. The client never derives band
    from score anywhere except SegmentedBar (grep over Sources: the only
    `>= 75`/`>= 50` banding site).
  - `Sources/DesignSystem/Sources/Labels/ClosedEnumLabels.swift` :34–50 — the D19
    owner: `ReadinessBand: DisplayLabel, DisplayColored` with "Ready"/"Ease Off"/
    "Recover" and `.coachPositive`/`.coachWarning`/`.coachNegative`.
- Callers of `.readiness(score:)` (complete, grep-verified):
  - `Sources/Features/TodayFeature/Sources/Readiness/ReadinessComponentView.swift`
    :66 — and :61–64 renders `store.readiness.band.label` + `.band.color` ("78 Ready")
    **immediately above the meter**: the visible drift is "Ease Off" (domain) over
    "Ease off" (private dupe) on one screen when the band is amber.
  - `Sources/Features/DesignSystemGallery/Sources/Pages/PrimitiveComponentPages.swift`
    :239–241 — `ForEach([10, 60, 88]) { SegmentedBar.readiness(score: $0) }` (gallery
    sample scores; no real band available — will pass explicit pairs).
- DesignSystem already imports DomainModels (CarbCyclingPattern.swift:1,
  ClosedEnumLabels.swift:1); SegmentedBar.swift currently imports only SwiftUI — the
  import is additive, no package-graph change.

## 3. suggestedDay case-sensitive match

- `Sources/DesignSystem/Sources/Composites/CarbCyclingPattern.swift` :44 —
  `dayTypePattern.first(where: { $0.suggestedDay == weekday.rawValue })`; a non-match
  falls to the `restDay` cut (:47–48) or empty — i.e. `"Tue"` **silently renders as a
  rest day**.
- `Sources/Models/DomainModels/Sources/Nutrition.swift` :72–81 — domain
  `DayTypePatternEntry.suggestedDay` is a documented **free** `String` ("not the
  `Weekday`" enum), mirroring the wire (`WireModels/Sources/WeeklyNutrition.swift`
  :39–49, openapi free string). Mapping passes it through verbatim.
- `ClosedEnums.swift` :65–67 — `Weekday: String … case mon…sun` (lowercase raw
  values). Case-insensitive resolution = `Weekday(rawValue: raw.lowercased())`.
- Contrast: `PlannedSession.suggestedDay` is already typed `Weekday?` on the wire and
  `WeekRhythmComponent`/`WeeklySessionRow` compare enum values — no equivalent bug
  there. Only the nutrition pattern entry carries the free string.
- Fixtures: `CarbCyclingPatternPage.swift` :24–27, :40–42 use lowercase
  (`"tue"`/`"wed"`/…) — snapshot PNGs unaffected by the fix.
  `CarbCyclingPatternSnapshotTests` renders those gallery sections.
- `ValueTypeTests.swift` in `DomainModels/Tests` is the natural home for the
  normalization cases (plain value-type behavior tests already live there).

## 4. Gates and snapshot machinery

- `Makefile`: `test` = `swift test` on the macOS host (snapshot targets are
  `#if canImport(UIKit)`-guarded → compile empty on host); snapshot tests run only via
  `test-snapshots`/`record-snapshots` on the pinned sim — ship stage owns that.
- Readiness-meter snapshots that will diff on the label unification:
  `Sources/DesignSystem/Tests/DesignSystemSnapshotTests/BarsSnapshotTests.swift`
  (readiness section renders scores 10/60/88 → all three axis labels), 
  `Sources/Features/TodayFeature/Tests/TodayFeatureSnapshotTests/ReadinessSnapshotTests.swift`,
  and `TodayViewSnapshotTests.swift` cases that show the meter.
