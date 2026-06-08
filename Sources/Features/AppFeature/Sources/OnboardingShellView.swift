import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The onboarding branch's view — a minimal Connect step (Phase 7.1 scaffold). Shows a neutral connect
/// prompt, or a "token invalid — reconnect" banner when routed here by a 401 (`reason: .tokenInvalid`).
/// The token field / `GET /probe` call is Phase 7.2; this only sends the stub `connectTapped`.
struct OnboardingShellView: View {
  let store: StoreOf<OnboardingFeature>

  var body: some View {
    VStack(spacing: CoachSpacing.spaceLg) {
      Spacer()

      Image(systemName: Icon.exercise.systemName)
        .font(.system(size: 56))
        .foregroundStyle(.coachAccent)

      VStack(spacing: CoachSpacing.spaceSm) {
        Text("Coach")
          .font(.coachText2xl)
          .foregroundStyle(.coachForeground)
        Text("Connect your account to start training.")
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
          .multilineTextAlignment(.center)
      }

      if store.step == .connect(reason: .tokenInvalid) {
        Banner(
          icon: Icon.reconnect.systemName,
          tone: .negative,
          title: "Token invalid",
          message: "Your session expired — reconnect to continue."
        )
      }

      Spacer()

      PrimaryButton("Connect", icon: Icon.reconnect.systemName) {
        store.send(.connectTapped)
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.coachBackground)
  }
}
