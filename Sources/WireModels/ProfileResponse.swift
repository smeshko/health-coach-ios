import Foundation

/// The `/profile` response (`openapi.yaml` `ProfileResponse`).
public struct ProfileResponse: Codable, Sendable, Equatable {
  public var athlete: AthleteOut
  public var zones: ZonesOut
  public var thresholds: ThresholdsOut
  public var meta: MetaOut

  public init(athlete: AthleteOut, zones: ZonesOut, thresholds: ThresholdsOut, meta: MetaOut) {
    self.athlete = athlete
    self.zones = zones
    self.thresholds = thresholds
    self.meta = meta
  }
}

/// Athlete profile (`openapi.yaml` `AthleteOut`). `sex` is a **free** string (semantic typing is
/// Phase 2.2).
public struct AthleteOut: Codable, Sendable, Equatable {
  public var age: Int
  public var sex: String
  public var heightCm: Int
  public var goalWeightKg: Double

  public init(age: Int, sex: String, heightCm: Int, goalWeightKg: Double) {
    self.age = age
    self.sex = sex
    self.heightCm = heightCm
    self.goalWeightKg = goalWeightKg
  }
}

// swiftlint:disable identifier_name

/// The five heart-rate zones (`openapi.yaml` `ZonesOut`).
public struct ZonesOut: Codable, Sendable, Equatable {
  public var z1: ZoneRange
  public var z2: ZoneRange
  public var z3: ZoneRange
  public var z4: ZoneRange
  public var z5: ZoneRange

  public init(z1: ZoneRange, z2: ZoneRange, z3: ZoneRange, z4: ZoneRange, z5: ZoneRange) {
    self.z1 = z1
    self.z2 = z2
    self.z3 = z3
    self.z4 = z4
    self.z5 = z5
  }
}

// swiftlint:enable identifier_name

/// A heart-rate zone range (`openapi.yaml` `ZoneRange`).
public struct ZoneRange: Codable, Sendable, Equatable {
  public var low: Int
  public var high: Int

  public init(low: Int, high: Int) {
    self.low = low
    self.high = high
  }
}

/// Physiological thresholds (`openapi.yaml` `ThresholdsOut`).
public struct ThresholdsOut: Codable, Sendable, Equatable {
  public var maxHr: Int
  public var rhrBaseline: Int
  public var hrvBaselineMs: Int
  public var easyHrCap: Int
  public var cadenceCurrentSpm: Int
  public var cadenceTargetSpm: Int

  public init(
    maxHr: Int,
    rhrBaseline: Int,
    hrvBaselineMs: Int,
    easyHrCap: Int,
    cadenceCurrentSpm: Int,
    cadenceTargetSpm: Int
  ) {
    self.maxHr = maxHr
    self.rhrBaseline = rhrBaseline
    self.hrvBaselineMs = hrvBaselineMs
    self.easyHrCap = easyHrCap
    self.cadenceCurrentSpm = cadenceCurrentSpm
    self.cadenceTargetSpm = cadenceTargetSpm
  }
}

/// Profile metadata (`openapi.yaml` `MetaOut`).
public struct MetaOut: Codable, Sendable, Equatable {
  public var constitutionVersion: String
  public var constantsRecomputedWeek: String?

  public init(constitutionVersion: String, constantsRecomputedWeek: String? = nil) {
    self.constitutionVersion = constitutionVersion
    self.constantsRecomputedWeek = constantsRecomputedWeek
  }
}
