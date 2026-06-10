import DesignSystem
import HealthKitClient

/// The user-facing HealthKit signal rows for the priming + degraded screens (Phase 7.3). This is the
/// **feature-local grouping seam** (DECISIONS #1): each row maps to a `Set<HealthDataCategory>` (the
/// Phase 3.3 vocabulary) — the only place rows↔categories are defined — which `HealthKitPriming`'s
/// `missingRows(from:)` reduction keys on for empty-delta degraded inference. The **labels** come from
/// `DesignSystem` (`signalLabel` / `primingGroupLabel`), never re-derived here, so no raw machine key
/// reaches a view (principle #2 / D19).
///
/// `allCases` is the degraded screen's 11 rows (Heart & recovery split into HR / HRV / resting HR to
/// match the design); `primingGroups` collapses them into the 8 priming-screen groups.
public enum PrimingRow: CaseIterable, Hashable, Sendable {
  case heartRate
  case hrv
  case restingHeartRate
  case sleep
  case steps
  case activeBasalEnergy
  case vo2Max
  case runningForm
  case workoutsEffort
  case bodyWeight
  case dietary

  /// The `HealthDataCategory` set this row covers. The union over `allCases` **equals** the full
  /// `HealthDataCategory` set and the assignment is disjoint (every category has exactly one home) —
  /// enforced by `HealthKitPrimingTests`. `respiratoryRate` folds into the Heart-rate row; `activity`
  /// (rings) folds into Active & basal energy; `runningDynamics` is the sole occupant of Running form
  /// (so the row is mandatory).
  var categories: Set<HealthDataCategory> {
    switch self {
    case .heartRate: [.heartRate, .respiratoryRate]
    case .hrv: [.hrv]
    case .restingHeartRate: [.restingHeartRate]
    case .sleep: [.sleep]
    case .steps: [.steps]
    case .activeBasalEnergy: [.activeEnergy, .basalEnergy, .activity]
    case .vo2Max: [.vo2Max]
    case .runningForm: [.runningDynamics]
    case .workoutsEffort: [.workouts, .effort]
    case .bodyWeight: [.bodyMass]
    case .dietary: [.dietary]
    }
  }

  /// The category whose `DesignSystem` label represents this row — labels are owned by DesignSystem, the
  /// row→category choice (vocabulary, not copy) is feature-local.
  var representativeCategory: HealthDataCategory {
    switch self {
    case .heartRate: .heartRate
    case .hrv: .hrv
    case .restingHeartRate: .restingHeartRate
    case .sleep: .sleep
    case .steps: .steps
    case .activeBasalEnergy: .activeEnergy
    case .vo2Max: .vo2Max
    case .runningForm: .runningDynamics
    case .workoutsEffort: .workouts
    case .bodyWeight: .bodyMass
    case .dietary: .dietary
    }
  }

  /// The degraded-screen per-row label (title/subtitle/icon) — from the `DesignSystem` boundary.
  var rowLabel: HealthSignalLabel { representativeCategory.signalLabel }

  /// The priming-screen group label — from the `DesignSystem` boundary (the group head's copy, e.g.
  /// "Heart & recovery"). Meaningful for `primingGroups`; other rows fall back to their per-row label.
  var groupLabel: HealthSignalLabel { representativeCategory.primingGroupLabel }

  /// The 8 priming-screen groups, in the design's order (Heart & recovery / Sleep / Activity & energy /
  /// Aerobic fitness / Running form / Workouts & effort / Body weight / Dietary intake).
  static var primingGroups: [PrimingRow] {
    [.heartRate, .sleep, .steps, .vo2Max, .runningForm, .workoutsEffort, .bodyWeight, .dietary]
  }
}
