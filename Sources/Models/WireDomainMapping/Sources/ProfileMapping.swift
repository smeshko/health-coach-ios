import DomainModels
import WireModels

/// Map a wire `ProfileResponse` to the domain `Profile`. **Non-throwing** — `ProfileResponse`
/// carries no closed-enum field (only numbers/strings + zone ranges), so there is no out-of-set
/// enum it could fail on (DECISIONS Decision 2).
public func domainProfile(_ dto: WireModels.ProfileResponse) -> DomainModels.Profile {
  DomainModels.Profile(
    athlete: DomainModels.Athlete(
      age: dto.athlete.age,
      sex: dto.athlete.sex,
      heightCm: dto.athlete.heightCm,
      goalWeightKg: dto.athlete.goalWeightKg
    ),
    zones: DomainModels.Zones(
      z1: zoneRange(dto.zones.z1),
      z2: zoneRange(dto.zones.z2),
      z3: zoneRange(dto.zones.z3),
      z4: zoneRange(dto.zones.z4),
      z5: zoneRange(dto.zones.z5)
    ),
    thresholds: DomainModels.Thresholds(
      maxHr: dto.thresholds.maxHr,
      rhrBaseline: dto.thresholds.rhrBaseline,
      hrvBaselineMs: dto.thresholds.hrvBaselineMs,
      easyHrCap: dto.thresholds.easyHrCap,
      cadenceCurrentSpm: dto.thresholds.cadenceCurrentSpm,
      cadenceTargetSpm: dto.thresholds.cadenceTargetSpm
    ),
    meta: DomainModels.ProfileMeta(
      constitutionVersion: dto.meta.constitutionVersion,
      constantsRecomputedWeek: dto.meta.constantsRecomputedWeek
    )
  )
}

private func zoneRange(_ dto: WireModels.ZoneRange) -> DomainModels.ZoneRange {
  DomainModels.ZoneRange(low: dto.low, high: dto.high)
}
