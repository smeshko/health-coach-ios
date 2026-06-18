import ComposableArchitecture
import StrengthTestFeature

/// You/Settings tab drill-down destinations. Filled by Phase 10.4 with the strength-test input screen
/// (pushed from the Strength-test row and the weekly-reminder deep link). One `@Reducer enum` per file
/// (colocating several crashes the type checker during macro expansion).
@Reducer
public enum SettingsPath {
  case strengthTest(StrengthTestFeature)
}

extension SettingsPath.State: Equatable {}
