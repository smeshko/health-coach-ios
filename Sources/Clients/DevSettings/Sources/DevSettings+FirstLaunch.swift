import DevSettings
import Foundation

public extension DevSettings {
  /// Seeds the DEBUG first-launch default coherently with the configured backend: when nothing is
  /// persisted yet, write `mock = !liveBackendConfigured`. Live-by-default holds **iff** a live backend
  /// is configured; an unconfigured install seeds mock so a fresh launch is usable instead of a
  /// guaranteed-failing live run (see the phase-18-1 PLAN.md "Seed mock on unconfigured DEBUG first
  /// launch" decision). What "configured" means is owned by the `APIBaseURL` resolver — the composition
  /// root passes its verdict in here. **DEBUG-only** — a no-op in RELEASE (where `useMockData` is
  /// already hard-`false`). Call this from the composition root *before* resolving `@Dependency`.
  ///
  /// Persisted-store semantics are unchanged: this writes once on first launch only; every later read
  /// still comes from the store, and the dev-menu toggle is the only mock/live control thereafter.
  /// (An explicit seeded value and an unpersisted slot read the same; seeding keeps the first-launch
  /// value deterministic and greppable.)
  static func seedFirstLaunchDefault(liveBackendConfigured: Bool, defaults: UserDefaults = .standard) {
    #if DEBUG
      let store = DevSettingsStore(defaults: defaults)
      if !store.hasPersistedMock() {
        store.writeMock(!liveBackendConfigured)
      }
    #endif
  }
}
