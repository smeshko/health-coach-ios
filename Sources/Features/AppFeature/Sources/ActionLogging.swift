import ComposableArchitecture
import LogClient

extension Reducer {
  /// Logs each action's nested case-label path under `.tca` at `.debug` (e.g. `main.tabSelected.weekly`)
  /// before delegating to the base reducer — the app-root action trace (DECISIONS #4). Descends only
  /// through **enum** associated values and stops at the first non-enum payload, so a case's *data*
  /// (strings, numbers, structs — anything that could be PII) is never logged, only structural labels.
  /// Volume is controlled by the existing per-category `DevSettings` gate in `LogClientLive`; apply once
  /// at the root only (per-feature application would duplicate lines and add cost).
  func logActions() -> some ReducerOf<Self> {
    ActionLoggingReducer(base: self)
  }
}

/// The higher-order reducer behind `logActions()` — observes (logs the action label) then delegates to
/// the base reducer; it never alters state or effects.
private struct ActionLoggingReducer<Base: Reducer>: Reducer {
  let base: Base
  @Dependency(\.log) var log

  func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    log.debug(actionLabel(action), category: .tca)
    return base.reduce(into: &state, action: action)
  }
}

/// The action's nested case-label path, descending only through enum associated values (structural) and
/// stopping at the first non-enum payload — so no associated data / PII is ever logged. A bare case (no
/// associated value) reflects to just its case name.
private func actionLabel(_ value: Any) -> String {
  let mirror = Mirror(reflecting: value)
  guard mirror.displayStyle == .enum, let child = mirror.children.first, let label = child.label else {
    return String(describing: value)
  }
  if Mirror(reflecting: child.value).displayStyle == .enum {
    return "\(label).\(actionLabel(child.value))"
  }
  return label
}
