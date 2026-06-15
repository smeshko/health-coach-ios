import DomainModels
import SwiftUI

// Closed-enum label conformances — exhaustive `switch` (no `default`), so a new `DomainModels` case is
// a compile error here, never a silent fallthrough (PRD §12.1/§12.3).

extension Card: DisplayLabel {
  public var label: String {
    switch self {
    case .easyRun: "Easy Run"
    case .longRun: "Long Run"
    case .progressionRun: "Progression Run"
    case .activeRecovery: "Active Recovery"
    case .threshold: "Threshold"
    case .vo2: "VO₂ Max"
    case .strides: "Strides"
    case .hiit: "HIIT"
    case .jumpRope: "Jump Rope"
    case .steadyCardio: "Steady Cardio"
    case .strengthPush: "Strength — Push"
    case .strengthPull: "Strength — Pull"
    case .strengthLower: "Strength — Lower"
    case .strengthFull: "Strength — Full Body"
    case .boxing: "Boxing"
    case .boxingTechnique: "Boxing Technique"
    case .footPrehab: "Foot Prehab"
    case .glutePrehab: "Glute Prehab"
    case .mobility: "Mobility"
    case .rest: "Rest"
    }
  }
}

extension ReadinessBand: DisplayLabel, DisplayColored {
  public var label: String {
    switch self {
    case .green: "Ready"
    case .amber: "Ease Off"
    case .red: "Recover"
    }
  }

  public var color: Color {
    switch self {
    case .green: .coachPositive
    case .amber: .coachWarning
    case .red: .coachNegative
    }
  }
}

extension DayType: DisplayLabel {
  public var label: String {
    switch self {
    case .hard: "Hard"
    case .moderate: "Moderate"
    case .rest: "Rest"
    }
  }
}

extension Intensity: DisplayLabel, DisplayIconed {
  public var label: String {
    switch self {
    case .easy: "Easy"
    case .quality: "Quality"
    case .recovery: "Recovery"
    }
  }

  public var iconName: String {
    switch self {
    case .easy: "figure.walk"
    case .quality: "bolt.fill"
    case .recovery: "leaf.fill"
    }
  }
}

extension Tier: DisplayLabel {
  public var label: String {
    switch self {
    case .core: "Core"
    case .extra: "Extra"
    }
  }
}

extension Weekday: DisplayLabel {
  public var label: String {
    switch self {
    case .mon: "Mon"
    case .tue: "Tue"
    case .wed: "Wed"
    case .thu: "Thu"
    case .fri: "Fri"
    case .sat: "Sat"
    case .sun: "Sun"
    }
  }

  /// The single-letter form for the compact week-rhythm row (`WeekRhythmRow`): M T W T F S S. DesignSystem
  /// owns labels (D19), and `label` ("Mon"/"Tue") has no one-letter form — this is the sanctioned site.
  public var shortLabel: String {
    switch self {
    case .mon: "M"
    case .tue: "T"
    case .wed: "W"
    case .thu: "T"
    case .fri: "F"
    case .sat: "S"
    case .sun: "S"
    }
  }
}
