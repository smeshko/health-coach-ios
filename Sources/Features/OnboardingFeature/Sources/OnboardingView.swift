import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The onboarding branch's root view — renders the current `Step`. The `.connect` step renders
/// `ConnectView` (Phase 7.2); the `.healthKitPriming` step is a placeholder until Phase 7.3. The
/// 401-bounce `reason: .tokenInvalid` shows a reconnect banner pinned over the top of the connect
/// content — a separate concern from `ConnectComponent`'s probe-failure error row (which keys off
/// `validation == .invalid`).
public struct OnboardingView: View {
  let store: StoreOf<OnboardingFeature>

  public init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  public var body: some View {
    switch store.step {
    case let .connect(reason):
      ConnectView(store: store.scope(state: \.connect, action: \.connect))
        .safeAreaInset(edge: .top) {
          if reason == .tokenInvalid {
            Banner(
              icon: "exclamationmark.triangle.fill",
              tone: .negative,
              title: "Token invalid",
              message: ErrorDisplay.unauthorized.label
            )
            .padding(.horizontal, CoachSpacing.spaceLg)
            .padding(.top, CoachSpacing.spaceLg)
          }
        }

    case .healthKitPriming:
      Text("Setting up…")
        .font(.coachTextLg)
        .foregroundStyle(.coachForegroundMuted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.coachBackground)
    }
  }
}
