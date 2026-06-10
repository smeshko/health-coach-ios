import HealthKitClient

/// The `HealthDataCategory` → human **label** boundary (Phase 7.3, DECISIONS #1) — extends Phase 5.1's
/// enum→label site so a raw Apple-Health machine key never reaches a view (principle #2 / D19). This is
/// the single source of the priming/degraded **copy**; the `PrimingRow → Set<HealthDataCategory>`
/// **grouping** (the degraded-inference seam) stays feature-local in `OnboardingFeature`.
///
/// Importing the `HealthKitClient` **interface** here is the recorded §4.4 widening (DECISIONS #1): the
/// imported symbol is a pure value enum, never `HealthKitClientLive`/the HealthKit framework, so
/// DesignSystem stays off every `*Live`/repository/wire target.

/// A health-signal label triple: the human title, a one-line "why it matters" subtitle, and an SF Symbol.
/// Settings (Epic 10, `HealthKitStatusComponent`) reuses the same labels for the in-app status surface.
public struct HealthSignalLabel: Equatable, Sendable {
  public let title: String
  public let subtitle: String
  public let iconName: String

  public init(title: String, subtitle: String, iconName: String) {
    self.title = title
    self.subtitle = subtitle
    self.iconName = iconName
  }
}

public extension HealthDataCategory {
  /// The per-category label — the degraded screen's per-row title (via the feature's representative
  /// category) and the Settings status label. Exhaustive `switch` (no `default`), so a new
  /// `HealthDataCategory` case is a compile error here, never a silent raw-key fallthrough.
  var signalLabel: HealthSignalLabel {
    switch self {
    case .heartRate:
      HealthSignalLabel(
        title: "Heart rate", subtitle: "Strain through a session.", iconName: "heart.fill"
      )
    case .hrv:
      HealthSignalLabel(
        title: "Heart rate variability", subtitle: "Overnight recovery balance.", iconName: "waveform.path.ecg"
      )
    case .restingHeartRate:
      HealthSignalLabel(
        title: "Resting heart rate", subtitle: "A baseline that drifts with load.", iconName: "heart"
      )
    case .sleep:
      HealthSignalLabel(
        title: "Sleep", subtitle: "Hours and quality drive next-day readiness.", iconName: "moon.fill"
      )
    case .steps:
      HealthSignalLabel(
        title: "Steps", subtitle: "Daily movement outside training.", iconName: "figure.walk"
      )
    case .activeEnergy:
      HealthSignalLabel(
        title: "Active & basal energy", subtitle: "Energy burned, moving and at rest.", iconName: "flame.fill"
      )
    case .basalEnergy:
      HealthSignalLabel(
        title: "Basal energy", subtitle: "Energy burned at rest.", iconName: "flame"
      )
    case .effort:
      HealthSignalLabel(
        title: "Effort (RPE)", subtitle: "How hard a session felt.", iconName: "gauge.medium"
      )
    case .vo2Max:
      HealthSignalLabel(
        title: "VO₂ max", subtitle: "Your endurance trend over time.", iconName: "lungs.fill"
      )
    case .bodyMass:
      HealthSignalLabel(
        title: "Body weight", subtitle: "A gentle long-term trend, not a daily verdict.", iconName: "scalemass.fill"
      )
    case .runningDynamics:
      HealthSignalLabel(
        title: "Running form", subtitle: "Cadence, stride length and ground contact.", iconName: "figure.run"
      )
    case .respiratoryRate:
      HealthSignalLabel(
        title: "Respiratory rate", subtitle: "Breaths per minute overnight.", iconName: "wind"
      )
    case .dietary:
      HealthSignalLabel(
        title: "Dietary intake", subtitle: "Calories and macros to fuel your training.", iconName: "fork.knife"
      )
    case .workouts:
      HealthSignalLabel(
        title: "Workouts & effort (RPE)", subtitle: "Sessions you log, with effort.", iconName: "dumbbell.fill"
      )
    case .activity:
      HealthSignalLabel(
        title: "Activity rings", subtitle: "Move, exercise and stand totals.", iconName: "circle.circle.fill"
      )
    }
  }

  /// The priming-screen **group** label, keyed on the group's head category — distinct from the per-row
  /// `signalLabel` (e.g. `heartRate` heads "Heart & recovery", not "Heart rate"). Non-head categories
  /// fall back to their `signalLabel` (the feature only reads this for the 8 group heads). Exhaustive.
  var primingGroupLabel: HealthSignalLabel {
    switch self {
    case .heartRate:
      HealthSignalLabel(
        title: "Heart & recovery", subtitle: "HR, HRV and resting HR — strain & recovery.", iconName: "heart.fill"
      )
    case .sleep:
      HealthSignalLabel(
        title: "Sleep", subtitle: "Hours and quality drive next-day readiness.", iconName: "moon.fill"
      )
    case .steps:
      HealthSignalLabel(
        title: "Activity & energy", subtitle: "Steps, active and basal energy burn.", iconName: "flame.fill"
      )
    case .vo2Max:
      HealthSignalLabel(
        title: "Aerobic fitness", subtitle: "VO₂ max — your endurance trend over time.", iconName: "lungs.fill"
      )
    case .runningDynamics:
      HealthSignalLabel(
        title: "Running form", subtitle: "Cadence, stride length and ground contact.", iconName: "figure.run"
      )
    case .workouts:
      HealthSignalLabel(
        title: "Workouts & effort", subtitle: "Sessions you log, with effort (RPE).", iconName: "dumbbell.fill"
      )
    case .bodyMass:
      HealthSignalLabel(
        title: "Body weight", subtitle: "A gentle long-term trend, not a daily verdict.", iconName: "scalemass.fill"
      )
    case .dietary:
      HealthSignalLabel(
        title: "Dietary intake", subtitle: "Calories and macros to fuel your training.", iconName: "fork.knife"
      )
    // Non-head categories never head a priming group (the feature only reads this for the 8 heads);
    // listed explicitly — not via `default` — so a new `HealthDataCategory` stays a compile error.
    case .hrv, .restingHeartRate, .activeEnergy, .basalEnergy, .effort, .respiratoryRate, .activity:
      signalLabel
    }
  }
}
