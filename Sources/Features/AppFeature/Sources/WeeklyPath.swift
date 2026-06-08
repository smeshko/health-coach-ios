import ComposableArchitecture

/// Week tab drill-down destinations (placeholder until Epic 9). One `@Reducer enum` per file — see
/// `TodayPath.swift` for why.
@Reducer
public enum WeeklyPath {
  case placeholder(PlaceholderFeature)
}

extension WeeklyPath.State: Equatable {}
