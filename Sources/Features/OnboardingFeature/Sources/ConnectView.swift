import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The Connect screen (`Connect` / `Connect Error` designs): a centered token-entry form over
/// `StoreOf<ConnectComponent>`. Renders the **connect** state and, when `validation == .invalid`, the
/// **error** state (tinted field + an inline error row). All color/spacing/radius/typography come from
/// `DesignSystem` tokens — no raw hex or magic numbers. The error row's copy is the fixed
/// `ErrorDisplay.unauthorized` label from the `DesignSystem` boundary (DECISIONS 2); the feature authors
/// no raw error string and there is no `APIError`→`ErrorDisplay` presenter here (every probe failure
/// shows the one §8.4 generic message).
///
/// Pure SwiftUI value code that compiles on the macOS host (the Swift/SPM host-build hazard) — no
/// iOS-only modifiers; the 401-bounce reason banner is the parent `OnboardingView`'s concern.
struct ConnectView: View {
  @Bindable var store: StoreOf<ConnectComponent>

  init(store: StoreOf<ConnectComponent>) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: CoachSpacing.spaceLg) {
      Spacer()

      VStack(spacing: CoachSpacing.spaceMd) {
        Image(systemName: "heart.fill")
          .font(.system(size: Metrics.glyph))
          .foregroundStyle(.coachOnAccent)
          .frame(width: Metrics.tile, height: Metrics.tile)
          .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(.coachAccent))

        VStack(spacing: CoachSpacing.spaceSm) {
          Text("Let's connect you")
            .font(.coachText2xl)
            .foregroundStyle(.coachForeground)
          Text("Enter the access token from your coach to start syncing your training and recovery.")
            .font(.coachTextMd)
            .foregroundStyle(.coachForegroundMuted)
            .multilineTextAlignment(.center)
        }
      }

      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        Text("Access token")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)

        HStack(spacing: CoachSpacing.spaceSm) {
          TextField("Paste your token", text: $store.token)
            .font(.coachTextMd)
            .foregroundStyle(.coachForeground)
            .autocorrectionDisabled()

          PasteButton(payloadType: String.self) { strings in
            if let value = strings.first { store.send(.tokenPasted(value)) }
          }
          .labelStyle(.titleOnly)
          .tint(.coachAccent)
        }
        .padding(CoachSpacing.spaceMd)
        .background(
          RoundedRectangle(cornerRadius: CoachRadius.sm)
            .fill(store.validation == .invalid ? Color.coachNegativeSoft : .coachSurfaceSunken)
        )
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.sm)
            .stroke(store.validation == .invalid ? Color.coachNegative : .coachBorder, lineWidth: 1)
        )

        if store.validation == .invalid {
          HStack(spacing: CoachSpacing.space2xs) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(ErrorDisplay.unauthorized.label)
          }
          .font(.coachTextXs)
          .foregroundStyle(.coachNegative)
        }
      }

      Text("This app is personal — there's no sign-up or password. Your token is provisioned by your coach.")
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundSubtle)
        .multilineTextAlignment(.center)

      Spacer()

      PrimaryButton("Connect") { store.send(.connectTapped) }
        .disabled(!store.canSubmit)
        .overlay {
          if store.validation == .validating {
            ProgressView().tint(.coachOnAccent)
          }
        }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.coachBackground)
  }
}

/// Glyph/tile geometry — named constants, not inline literals (mirrors the `DesignSystem` primitives'
/// `private enum Metrics` convention).
private enum Metrics {
  static let glyph: CGFloat = 28
  static let tile: CGFloat = 64
}

#Preview("Connect") {
  ConnectView(
    store: Store(initialState: ConnectComponent.State(token: "ahc_live_a8f2")) {
      ConnectComponent()
    }
  )
}

#Preview("Connect Error") {
  ConnectView(
    store: Store(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .invalid)) {
      ConnectComponent()
    }
  )
}
