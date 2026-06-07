import WireModels

/// A logical Apple-Health category — the unit the client requests authorization for and reports
/// status on (driving the degraded-permissions UX, PRD §5/§8.5). Each maps to one-or-more HK sample
/// types (in `HealthKitClientLive`) and to the wire `RecordType`s it produces.
public enum HealthDataCategory: String, CaseIterable, Sendable {
  case heartRate
  case hrv
  case restingHeartRate
  case sleep
  case steps
  case activeEnergy
  case basalEnergy
  case effort
  case vo2Max
  case bodyMass
  case runningDynamics
  case respiratoryRate
  case dietary
  case workouts
  case activity
}

/// Per-category authorization status. Read access is privacy-masked by Apple (a granted read type can
/// still report not-authorized), so this is a best-effort hint — the real contract is
/// empty-slice-not-error on delta reads.
public enum HealthAuthorizationStatus: Sendable, Equatable {
  case notDetermined
  case sharingAuthorized
  case sharingDenied
  case healthDataUnavailable
}

public extension HealthDataCategory {
  /// The wire `RecordType`s this category produces. `workouts`/`activity` produce no `RecordType`
  /// (they map to `WorkoutPayload`/`ActivitySummaryPayload`), so they return `[]`.
  var recordTypes: [RecordType] {
    switch self {
    case .heartRate: [.heartRate]
    case .hrv: [.heartRateVariabilitySdnn]
    case .restingHeartRate: [.restingHeartRate]
    case .sleep: [.sleepAnalysis]
    case .steps: [.stepCount]
    case .activeEnergy: [.activeEnergyBurned]
    case .basalEnergy: [.basalEnergyBurned]
    case .effort: [.physicalEffort]
    case .vo2Max: [.vo2Max]
    case .bodyMass: [.bodyMass]
    case .runningDynamics:
      [
        .runningSpeed, .runningPower, .runningCadence, .runningStrideLength,
        .runningGroundContactTime, .runningVerticalOscillation,
      ]
    case .respiratoryRate: [.respiratoryRate]
    case .dietary:
      [
        .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
        .dietaryFiber, .dietarySodium, .dietaryWater,
      ]
    case .workouts: []
    case .activity: []
    }
  }
}
