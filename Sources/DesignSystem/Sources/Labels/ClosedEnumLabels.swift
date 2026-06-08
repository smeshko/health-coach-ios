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

extension Zone: DisplayLabel, DisplayColored {
  public var label: String {
    switch self {
    case .z1: "Zone 1"
    case .z2: "Zone 2"
    case .z3: "Zone 3"
    case .z4: "Zone 4"
    case .z5: "Zone 5"
    }
  }

  public var color: Color {
    switch self {
    case .z1: .coachZ1
    case .z2: .coachZ2
    case .z3: .coachZ3
    case .z4: .coachZ4
    case .z5: .coachZ5
    }
  }
}

extension ReadinessBand: DisplayLabel, DisplayColored, DisplayIconed {
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

  public var iconName: String {
    switch self {
    case .green: "checkmark.circle.fill"
    case .amber: "exclamationmark.triangle.fill"
    case .red: "pause.circle.fill"
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

extension Intensity: DisplayLabel, DisplayColored, DisplayIconed {
  public var label: String {
    switch self {
    case .easy: "Easy"
    case .quality: "Quality"
    case .recovery: "Recovery"
    }
  }

  public var color: Color {
    switch self {
    case .easy: .coachEasy
    case .quality: .coachQuality
    case .recovery: .coachRecovery
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

extension NarrativeType: DisplayLabel {
  public var label: String {
    switch self {
    case .summary: "Summary"
    case .session: "Session"
    case .nutrition: "Nutrition"
    case .caution: "Caution"
    case .plan: "Plan"
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
}
