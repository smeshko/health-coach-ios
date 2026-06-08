import ComposableArchitecture

/// You/Settings tab drill-down destinations (placeholder until Epic 10; the tab root itself is filled
/// minimally by Phase 7.4). One `@Reducer enum` per file — see `TodayPath.swift` for why.
@Reducer
public enum SettingsPath {
  case placeholder(PlaceholderFeature)
}

extension SettingsPath.State: Equatable {}
