import Foundation

/// A nutrition intake summary (e.g. yesterday's intake on the daily brief).
///
/// The six macro totals are optional (`nil` = nothing logged); `vsTarget` is **non-optional** (always
/// present even when the totals are null).
public struct IntakeSummary: Equatable, Codable, Sendable {
  public var date: Date
  public var caloriesKcal: Int?
  public var proteinG: Int?
  public var carbsG: Int?
  public var fatG: Int?
  public var fiberG: Int?
  public var waterL: Double?
  public var vsTarget: IntakeVsTarget

  public init(
    date: Date,
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

/// Intake measured against target.
public struct IntakeVsTarget: Equatable, Codable, Sendable {
  public var caloriesPct: Double
  public var proteinHit: Bool

  public init(caloriesPct: Double, proteinHit: Bool) {
    self.caloriesPct = caloriesPct
    self.proteinHit = proteinHit
  }
}
