import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The daily session surface (`Row.png` / `Today · Exercise.png`) — the `DesignSystem` `SessionCard` for the
/// **committed** session (narrative in-card, zone bar reflecting `zoneRange(for:)`), with the warm skip
/// affordance wired.
///
/// Interim single-card presentation: the horizontal **carousel** of candidates (peek + pager dots,
/// tap-to-commit) is built in the next task. A plain store-driven view (not the `@ViewAction` macro): the
/// card stays pure — it renders labels and forwards taps through the injected `onSkip` slot; the selection
/// lives in the reducer.
public struct SessionFeatureView: View {
  @Bindable var store: StoreOf<SessionFeature>

  public init(store: StoreOf<SessionFeature>) {
    self.store = store
  }

  public var body: some View {
    SessionCard(
      store.selectedSession,
      zoneRange: store.state.zoneRange(for: store.selectedSession),
      narrative: store.narrative,
      // The card shows the warm "Skipping is fine today" only when `onSkip` is non-nil (`skipOk`). A
      // rest-day session renders the card's own "Rest is training too." footer and ignores the slot.
      onSkip: store.skipOk ? { store.send(.skipTapped) } : nil
    )
  }
}
