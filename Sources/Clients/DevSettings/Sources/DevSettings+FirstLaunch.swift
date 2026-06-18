import DevSettings
import Foundation

public extension DevSettings {
  /// Seeds the DEBUG first-launch default: when nothing is persisted yet, write `mock = false` so a fresh
  /// install runs on the **live** backend (the DEBUG build is the one installed on a real phone, where
  /// fixtures aren't wanted — release audit 2026-06-18, item 5). **DEBUG-only** — a no-op in RELEASE
  /// (where `useMockData` is already hard-`false`). Call this from the composition root *before* resolving
  /// `@Dependency`.
  ///
  /// NOTE: live data needs a reachable `APIClient` base URL; the default is still `http://localhost:8000`
  /// (`APIClient+Live.swift`), so set a production URL at the composition root for the phone to connect.
  ///
  /// Persisted-store semantics are unchanged: this writes once on first launch only; every later read
  /// still comes from the store, and the dev-menu toggle is the only mock/live control thereafter. (An
  /// explicit seeded `false` and an unpersisted slot both read as live; seeding keeps the first-launch
  /// value deterministic and greppable.)
  static func seedFirstLaunchDefault(defaults: UserDefaults = .standard) {
    #if DEBUG
      let store = DevSettingsStore(defaults: defaults)
      if !store.hasPersistedMock() {
        store.writeMock(false)
      }
    #endif
  }
}
