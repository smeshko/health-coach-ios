import Foundation

/// The athlete profile (domain twin of wire `ProfileResponse`).
public struct Profile: Equatable, Codable, Sendable {
  public var athlete: Athlete
  public var zones: Zones
  public var thresholds: Thresholds
  public var meta: ProfileMeta

  public init(athlete: Athlete, zones: Zones, thresholds: Thresholds, meta: ProfileMeta) {
    self.athlete = athlete
    self.zones = zones
    self.thresholds = thresholds
    self.meta = meta
  }
}

/// Athlete constants.
public struct Athlete: Equatable, Codable, Sendable {
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

/// The five heart-rate zones.
public struct Zones: Equatable, Codable, Sendable {
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

/// A heart-rate zone range.
public struct ZoneRange: Equatable, Codable, Sendable {
  public var low: Int
  public var high: Int

  public init(low: Int, high: Int) {
    self.low = low
    self.high = high
  }
}

/// Physiological thresholds.
public struct Thresholds: Equatable, Codable, Sendable {
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

/// Profile metadata.
public struct ProfileMeta: Equatable, Codable, Sendable {
  public var constitutionVersion: String
  public var constantsRecomputedWeek: String?

  public init(constitutionVersion: String, constantsRecomputedWeek: String? = nil) {
    self.constitutionVersion = constitutionVersion
    self.constantsRecomputedWeek = constantsRecomputedWeek
  }
}
