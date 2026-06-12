/// The icon registry — the Iconography reference's set as named SF-Symbol entries with a role, so
/// components reference `Icon` cases (and the 5.5 gallery's Icons subpage can iterate the registry).
/// SF Symbols only — no bundled icon assets (the reference's "use SF variants in the iOS build"; use
/// `.fill` variants for active/emphasis).
public enum Icon: String, CaseIterable, Sendable {
  // Tab bar / nav.
  case today
  case week
  case you
  // Segmented control.
  case exercise
  case nutrition
  // Actions / states.
  case checkmark
  case prehab
  case drop
  // Health / loading.
  case heartPulse

  /// The SF Symbol name.
  public var systemName: String {
    switch self {
    case .today: "sun.max.fill"
    case .week: "calendar"
    case .you: "person"
    case .exercise: "figure.run"
    case .nutrition: "fork.knife"
    case .checkmark: "checkmark"
    case .prehab: "plus.circle.fill"
    case .drop: "drop.fill"
    case .heartPulse: "heart.fill"
    }
  }

  /// A human role/label for the gallery's Icons subpage.
  public var role: String {
    switch self {
    case .today: "Today"
    case .week: "Week"
    case .you: "You"
    case .exercise: "Exercise"
    case .nutrition: "Nutrition"
    case .checkmark: "Checkmark"
    case .prehab: "Add-on"
    case .drop: "Hydration"
    case .heartPulse: "Heart / health"
    }
  }
}
