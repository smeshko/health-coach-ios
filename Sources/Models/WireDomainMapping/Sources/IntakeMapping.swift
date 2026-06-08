import DomainModels
import WireModels

/// Map a wire `IntakeSummary` to the domain. Non-throwing — no closed-enum field. Reused by
/// `BriefMapping` for `intakeYesterday`.
public func domainIntake(_ dto: WireModels.IntakeSummary) -> DomainModels.IntakeSummary {
  DomainModels.IntakeSummary(
    date: dto.date.value,
    caloriesKcal: dto.caloriesKcal,
    proteinG: dto.proteinG,
    carbsG: dto.carbsG,
    fatG: dto.fatG,
    fiberG: dto.fiberG,
    waterL: dto.waterL,
    vsTarget: DomainModels.IntakeVsTarget(
      caloriesPct: dto.vsTarget.caloriesPct,
      proteinHit: dto.vsTarget.proteinHit
    )
  )
}
