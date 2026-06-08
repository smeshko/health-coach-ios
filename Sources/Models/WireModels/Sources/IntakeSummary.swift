import Foundation

/// Yesterday's nutrition intake summary (`openapi.yaml` `IntakeSummary`). `date` is a calendar
/// `date`. **`vsTarget` is required** even when the macro totals are all `null` (the macro fields
/// are optional, `vsTarget` is not).
public struct IntakeSummary: Codable, Sendable, Equatable {
  public var date: WireCalendarDate
  public var caloriesKcal: Int?
  public var proteinG: Int?
  public var carbsG: Int?
  public var fatG: Int?
  public var fiberG: Int?
  public var waterL: Double?
  public var vsTarget: IntakeVsTarget

  public init(
    date: WireCalendarDate,
    caloriesKcal: Int? = nil,
    proteinG: Int? = nil,
    carbsG: Int? = nil,
    fatG: Int? = nil,
    fiberG: Int? = nil,
    waterL: Double? = nil,
    vsTarget: IntakeVsTarget
  ) {
    self.date = date
    self.caloriesKcal = caloriesKcal
    self.proteinG = proteinG
    self.carbsG = carbsG
    self.fatG = fatG
    self.fiberG = fiberG
    self.waterL = waterL
    self.vsTarget = vsTarget
  }
}

/// Intake measured against target (`openapi.yaml` `IntakeVsTarget`).
public struct IntakeVsTarget: Codable, Sendable, Equatable {
  public var caloriesPct: Double
  public var proteinHit: Bool

  public init(caloriesPct: Double, proteinHit: Bool) {
    self.caloriesPct = caloriesPct
    self.proteinHit = proteinHit
  }
}
