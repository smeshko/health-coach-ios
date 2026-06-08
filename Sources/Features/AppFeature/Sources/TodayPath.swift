import ComposableArchitecture

/// Today tab drill-down destinations (placeholder until Epic 8).
///
/// NOTE: each `*Path` enum lives in its own file on purpose — colocating several single-case
/// `@Reducer enum`s in one source file crashes the Swift 6.3 type checker (signal 11) during macro
/// expansion. One enum per file sidesteps it.
@Reducer
public enum TodayPath {
  case placeholder(PlaceholderFeature)
}

// `StackState<TodayPath.State>` (in `MainTabs.State`) requires the macro-generated case-state enum to
// be `Equatable`; the payloads already are, so an empty extension synthesises it.
extension TodayPath.State: Equatable {}
