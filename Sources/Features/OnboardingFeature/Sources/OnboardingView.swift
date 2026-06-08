import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The onboarding branch's root view — renders the current `Step`. The `.connect` step's screen is a
/// **placeholder here in TASK-001** (the real `ConnectView` lands in TASK-002); the `.healthKitPriming`
/// step is a placeholder until Phase 7.3. The 401-bounce `reason: .tokenInvalid` shows a reconnect
/// banner above the connect content (a separate concern from `ConnectComponent`'s probe-failure error
/// row).
public struct OnboardingView: View {
  let store: StoreOf<OnboardingFeature>

  public init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  public var body: some View {
    switch store.step {
    case let .connect(reason):
      VStack(spacing: CoachSpacing.spaceLg) {
        if reason == .tokenInvalid {
          Banner(
            icon: "exclamationmark.triangle.fill",
            tone: .negative,
            title: "Token invalid",
            message: ErrorDisplay.unauthorized.label
          )
        }
        Spacer()
        Text("Let's connect you")
          .font(.coachText2xl)
          .foregroundStyle(.coachForeground)
        Spacer()
      }
      .padding(CoachSpacing.spaceLg)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)

    case .healthKitPriming:
      Text("Setting up…")
        .font(.coachTextLg)
        .foregroundStyle(.coachForegroundMuted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.coachBackground)
    }
  }
}
