import Foundation

// The ten closed wire enums (`openapi.yaml` `enum` schemas). Each declares explicit String
// rawValues where the wire value is snake_case/lowercase; where the Swift case name already equals
// the rawValue (e.g. `core`, `green`, `z1`) no explicit rawValue is given. None is used directly as
// a DTO field type — fields wrap them in `WireEnum<…>` for unknown-tolerant decode (DECISIONS.md
// Decision 1).

/// HealthKit record types synced to the backend (`RecordType`, 24 values).
public enum RecordType: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case heartRate = "heart_rate"
  case heartRateVariabilitySdnn = "heart_rate_variability_sdnn"
  case restingHeartRate = "resting_heart_rate"
  case sleepAnalysis = "sleep_analysis"
  case stepCount = "step_count"
  case activeEnergyBurned = "active_energy_burned"
  case basalEnergyBurned = "basal_energy_burned"
  case physicalEffort = "physical_effort"
  case vo2Max = "vo2_max"
  case bodyMass = "body_mass"
  case runningSpeed = "running_speed"
  case runningPower = "running_power"
  case runningCadence = "running_cadence"
  case runningStrideLength = "running_stride_length"
  case runningGroundContactTime = "running_ground_contact_time"
  case runningVerticalOscillation = "running_vertical_oscillation"
  case respiratoryRate = "respiratory_rate"
  case dietaryEnergyConsumed = "dietary_energy_consumed"
  case dietaryProtein = "dietary_protein"
  case dietaryCarbohydrates = "dietary_carbohydrates"
  case dietaryFatTotal = "dietary_fat_total"
  case dietaryFiber = "dietary_fiber"
  case dietarySodium = "dietary_sodium"
  case dietaryWater = "dietary_water"
}

/// The workout/session card catalogue (`WorkoutCard`, 20 values).
public enum WorkoutCard: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case easyRun = "easy_run"
  case longRun = "long_run"
  case progressionRun = "progression_run"
  case activeRecovery = "active_recovery"
  case threshold
  case vo2
  case strides
  case hiit
  case jumpRope = "jump_rope"
  case steadyCardio = "steady_cardio"
  case strengthPush = "strength_push"
  case strengthPull = "strength_pull"
  case strengthLower = "strength_lower"
  case strengthFull = "strength_full"
  case boxing
  case boxingTechnique = "boxing_technique"
  case footPrehab = "foot_prehab"
  case glutePrehab = "glute_prehab"
  case mobility
  case rest
}

/// Heart-rate zones (`Zone`, z1–z5).
public enum Zone: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  // swiftlint:disable:next identifier_name
  case z1, z2, z3, z4, z5
}

/// Days of the week (`Weekday`, mon–sun).
public enum Weekday: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case mon, tue, wed, thu, fri, sat, sun
}

/// Session tier (`Tier`).
public enum Tier: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case core, extra
}

/// Day type (`DayType`).
public enum DayType: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case hard, moderate, rest
}

/// Session intensity (`Intensity`).
public enum Intensity: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case easy, quality, recovery
}

/// Narrative section type (`NarrativeType`).
public enum NarrativeType: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case summary, session, nutrition, caution, plan
}

/// Readiness band (`ReadinessBand`).
public enum ReadinessBand: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case green, amber, red
}

/// Error envelope codes (`ErrorCode`).
public enum ErrorCode: String, CaseIterable, Codable, Sendable, Hashable, WireEnumWrapped {
  case validationError = "validation_error"
  case unauthorized
  case notFound = "not_found"
  case briefGenerationFailed = "brief_generation_failed"
  case upstreamTimeout = "upstream_timeout"
  case internalError = "internal_error"
}
