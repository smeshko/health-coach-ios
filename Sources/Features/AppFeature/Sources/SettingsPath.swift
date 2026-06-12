import ComposableArchitecture

/// You/Settings tab drill-down destinations — caseless until Epic 10 adds real destinations
/// (DECISIONS D1; the tab root itself is filled minimally by Phase 7.4). The named `SettingsPath`
/// slot + its `StackState`/`.forEach` survive for 10.2 to fill. One `@Reducer enum` per file
/// (colocating several crashes the type checker during macro expansion).
@Reducer
public enum SettingsPath {}

extension SettingsPath.State: Equatable {}
