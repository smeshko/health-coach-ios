import ComposableArchitecture

/// Week tab drill-down destinations — caseless until Epic 9 adds real destinations (DECISIONS D1).
/// The named `WeeklyPath` slot + its `StackState`/`.forEach` survive for 9.1 to fill. One
/// `@Reducer enum` per file (colocating several crashes the type checker during macro expansion).
@Reducer
public enum WeeklyPath {}

extension WeeklyPath.State: Equatable {}
