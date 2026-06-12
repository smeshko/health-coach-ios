import DomainModels
import WireModels

// The canned `/profile` fixture. Phase 11.3 folded the wire profile twins into the canonical
// `DomainModels.Profile` (`ProfileResponse` is now a typealias for it), so this is built from the
// DomainModels types. It lives in its own file because importing `DomainModels` into
// `APIClient+TestValue.swift` would make the brief DTOs (`Readiness`, `MacroFocus`, …) ambiguous with
// their domain twins — this file references only the profile types, which have no such collision.
extension CannedResponses {
  static let profile = ProfileResponse(
    athlete: Athlete(age: 34, sex: "male", heightCm: 182, goalWeightKg: 75),
    zones: Zones(
      z1: ZoneRange(low: 100, high: 130),
      z2: ZoneRange(low: 131, high: 145),
      z3: ZoneRange(low: 146, high: 160),
      z4: ZoneRange(low: 161, high: 175),
      z5: ZoneRange(low: 176, high: 190)
    ),
    thresholds: Thresholds(
      maxHr: 190, rhrBaseline: 48, hrvBaselineMs: 65, easyHrCap: 150,
      cadenceCurrentSpm: 172, cadenceTargetSpm: 180
    ),
    meta: ProfileMeta(constitutionVersion: "v3")
  )
}
