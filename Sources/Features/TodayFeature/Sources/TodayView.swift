import ComposableArchitecture
import SwiftUI

/// The Today tab's root view — switches **exhaustively** over `store.briefState` (no `default:`), so the
/// 8.2/8.3/8.4 phases add *content* to the `ready` branch without ever missing a lifecycle render path.
///
/// TASK-001 ships per-case placeholders + the sub-section seam markers; the designed shell chrome
/// (header, "Synced" pill, Exercise | Nutrition segmented toggle, and the loading/generating/sync-failed/
/// error states styled from `DesignSystem`) is fleshed out in TASK-005.
public struct TodayView: View {
  @Bindable var store: StoreOf<TodayFeature>

  public init(store: StoreOf<TodayFeature>) {
    self.store = store
  }

  public var body: some View {
    switch store.briefState {
    case .idle:
      Color.clear
    case .syncing:
      ProgressView()
    case .generating:
      ProgressView()
    case .ready:
      VStack {
        // MARK: - Phase 8.2 readiness

        // MARK: - Phase 8.3 session

        // MARK: - Phase 8.4 nutrition

        Text("Ready")
      }
    case .syncFailed:
      Text("Couldn't sync")
    case .error:
      Text("Something went wrong")
    }
  }
}
