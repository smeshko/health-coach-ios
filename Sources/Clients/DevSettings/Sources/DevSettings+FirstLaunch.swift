import DevSettings
import Foundation

public extension DevSettings {
  /// Seeds the DEBUG first-launch default: when nothing is persisted yet, write `mock = true` so a fresh
  /// install runs on fixtures with zero backend. **DEBUG-only** — a no-op in RELEASE (where `useMockData`
  /// is hard-`false`). Call this from the composition root *before* resolving `@Dependency`.
  ///
  /// Persisted-store semantics are unchanged: this writes once on first launch only; every later read
  /// still comes from the store, and the dev-menu toggle is the only mock/live control thereafter.
  static func seedFirstLaunchDefault(defaults: UserDefaults = .standard) {
    #if DEBUG
      let store = DevSettingsStore(defaults: defaults)
      if !store.hasPersistedMock() {
        store.writeMock(true)
      }
    #endif
  }
}
