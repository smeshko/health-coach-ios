import APIClientLive
import Foundation

/// Build-time configuration read once at the composition root (Phase 18.1 / audit CR-1). Thin by
/// design: all resolution rules (https-only off DEBUG+simulator, localhost fallback, loopback
/// rejection) live — unit-tested — in `APIBaseURL` (APIClientLive); this only points it at the app
/// bundle. `APIClientLive` may be imported here because the App target IS the composition root.
enum AppConfig {
  /// The server base URL from the `APIBaseURL` Info.plist key (backed by the `API_BASE_URL` build
  /// setting, shipped empty in the repo). `nil` ⇒ unconfigured: `CoachApp` installs the throwing
  /// `.unconfigured` client and seeds mock on a DEBUG first launch.
  static let apiBaseURL: URL? = APIBaseURL.resolve(bundle: .main)
}
