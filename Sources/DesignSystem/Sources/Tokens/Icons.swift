/// The icon registry — the Iconography reference's set as named SF-Symbol entries with a role, so
/// components reference `Icon` cases (and the 5.5 gallery's Icons subpage can iterate the registry).
/// SF Symbols only — no bundled icon assets (the reference's "use SF variants in the iOS build"; use
/// `.fill` variants for active/emphasis).
public enum Icon: String, CaseIterable, Sendable {
  // Tab bar / nav.
  case today
  case week
  case trends
  case you
  // Segmented control.
  case exercise
  case nutrition
  // Status bar.
  case cellular
  case wifi
  case battery
  // Actions / states.
  case checkmark
  case arrowRight
  case reconnect
  case retry
  case success
  case empty
  case prehab
  case ruler
  // Rest-day.
  case restHero
  case drop
  // Health / loading.
  case heartPulse

  /// The SF Symbol name.
  public var systemName: String {
    switch self {
    case .today: "sun.max.fill"
    case .week: "calendar"
    case .trends: "chart.line.uptrend.xyaxis"
    case .you: "person"
    case .exercise: "figure.run"
    case .nutrition: "fork.knife"
    case .cellular: "cellularbars"
    case .wifi: "wifi"
    case .battery: "battery.100"
    case .checkmark: "checkmark"
    case .arrowRight: "arrow.right"
    case .reconnect: "link"
    case .retry: "arrow.clockwise"
    case .success: "checkmark.circle.fill"
    case .empty: "tray"
    case .prehab: "plus.circle.fill"
    case .ruler: "ruler"
    case .restHero: "leaf.fill"
    case .drop: "drop.fill"
    case .heartPulse: "heart.fill"
    }
  }

  /// A human role/label for the gallery's Icons subpage.
  public var role: String {
    switch self {
    case .today: "Today"
    case .week: "Week"
    case .trends: "Trends"
    case .you: "You"
    case .exercise: "Exercise"
    case .nutrition: "Nutrition"
    case .cellular: "Cellular"
    case .wifi: "Wi-Fi"
    case .battery: "Battery"
    case .checkmark: "Checkmark"
    case .arrowRight: "Forward"
    case .reconnect: "Reconnect"
    case .retry: "Retry"
    case .success: "Success"
    case .empty: "Empty"
    case .prehab: "Add-on"
    case .ruler: "Distance"
    case .restHero: "Rest"
    case .drop: "Hydration"
    case .heartPulse: "Heart / health"
    }
  }
}
