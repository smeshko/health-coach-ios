import Foundation

// The two wire-only closed enums (RecordType, ErrorCode) — `openapi.yaml` `enum` schemas with no
// domain twin. Every other closed wire enum is now shared from `DomainModels` (Phase 11.3): DTO
// fields reference the domain types directly and decode strictly. These two have no domain
// counterpart, so they stay declared here as plain String-backed enums.

/// HealthKit record types synced to the backend (`RecordType`, 24 values).
public enum RecordType: String, CaseIterable, Codable, Sendable, Hashable {
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

/// Error envelope codes (`ErrorCode`).
public enum ErrorCode: String, CaseIterable, Codable, Sendable, Hashable {
  case validationError = "validation_error"
  case unauthorized
  case notFound = "not_found"
  case briefGenerationFailed = "brief_generation_failed"
  case upstreamTimeout = "upstream_timeout"
  case internalError = "internal_error"
}
