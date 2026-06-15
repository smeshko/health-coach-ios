import ComposableArchitecture
import DomainModels
import SwiftUI

/// The "This Week" tab's root view. Switches **exhaustively** over `store.weeklyState` (no `default:`) so
/// the 9.2/9.3 phases add *content* to the `ready` branch without ever missing a lifecycle render path.
/// The shell chrome (title, week-range subtitle, the Exercise | Nutrition `SegTabs` toggle, the plan card,
/// the dot-row) is fleshed out in TASK-005; this is the lifecycle skeleton + the 9.2/9.3 seam markers.
public struct WeeklyView: View {
  let store: StoreOf<WeeklyFeature>

  public init(store: StoreOf<WeeklyFeature>) {
    self.store = store
  }

  public var body: some View {
    switch store.weeklyState {
    case .idle:
      Color.clear
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case let .ready(plan, _):
      // The shell + budgets render here in TASK-004/005. The two seams below are where the later phases
      // plug their `ready` content into this stable parent without restructuring it.
      // MARK: - Phase 9.2 core/extra sessions
      // MARK: - Phase 9.3 weekly nutrition
      Text(plan.isoWeek)
    case .error:
      Text("Couldn't load this week")
    }
  }
}
