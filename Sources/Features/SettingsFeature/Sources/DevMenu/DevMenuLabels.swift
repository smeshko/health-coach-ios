#if DEBUG
  import DevSettings
  import LogClient
  import SampleData

  // Human-readable labels for the DEBUG dev menu. Kept in the dev-menu (view) layer on purpose: these are
  // presentation strings, deliberately NOT added to the shared SampleData / DevSettings / LogClient
  // interfaces (PLAN DECISIONS #2 — the dev menu owns its labels rather than coupling those modules to a
  // label table). `#if DEBUG`, like the rest of the menu, so they compile out of RELEASE.

  extension SampleScenario {
    /// Short label shown under its endpoint's scenario picker (the endpoint name is already the row).
    var devMenuLabel: String {
      switch self {
      case .dailyBriefGreen: "Green"
      case .dailyBriefAmber: "Amber"
      case .dailyBriefRed: "Red"
      case .dailyBriefRestGIFlare: "Rest — GI flare"
      case .dailyBriefRestIllness: "Rest — illness"
      case .dailyBriefRestKnee: "Rest — knee"
      case .dailyBriefNoFood: "No food logged"
      case .weeklyPlanDeload: "Deload week"
      case .profile: "Profile"
      case .syncResponse: "Sync response"
      }
    }
  }

  extension DevEndpoint {
    /// The endpoint's row label in the scenario picker list.
    var devMenuLabel: String {
      switch self {
      case .dailyBrief: "Daily Brief"
      case .weeklyPlan: "Weekly Plan"
      case .profile: "Profile"
      case .sync: "Sync"
      }
    }
  }

  extension LogCategory {
    /// The log category's row label in the LOGGING section.
    var devMenuLabel: String {
      switch self {
      case .http: "Network (HTTP)"
      case .tca: "State (TCA)"
      case .lifecycle: "Lifecycle"
      case .app: "App"
      }
    }
  }

  extension LogLevel {
    /// The level's label in the log viewer's minimum-severity picker + per-row badge.
    var devMenuLabel: String {
      switch self {
      case .debug: "Debug"
      case .info: "Info"
      case .notice: "Notice"
      case .error: "Error"
      }
    }
  }

  extension DateRange {
    /// The range's label in the log viewer's date-filter picker.
    var devMenuLabel: String {
      switch self {
      case .all: "All time"
      case .last15min: "Last 15 min"
      case .lastHour: "Last hour"
      case .today: "Today"
      case .last24h: "Last 24h"
      }
    }
  }
#endif
