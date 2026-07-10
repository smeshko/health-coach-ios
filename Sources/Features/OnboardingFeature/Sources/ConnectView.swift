import ComposableArchitecture
import DesignSystem
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// The Connect screen (`Connect` / `Connect Error` designs): a **left-aligned** token-entry form over
/// `StoreOf<ConnectComponent>`. Renders three stories: the **connect** state, and on a failed probe one
/// of two **error** states (tinted field + an inline error row) — `validation == .invalid` (the server
/// REJECTED the token, 401) and `validation == .unreachable` (the server never ANSWERED — transport,
/// timeout, unconfigured client), so a down server can't masquerade as a bad token (Phase 18.3). All
/// color/spacing/radius/typography come from `DesignSystem` tokens — no raw hex or magic numbers. The
/// error rows' copy is the fixed `ErrorDisplay.tokenRejected` / `.serverUnreachable` labels from the
/// `DesignSystem` boundary (DECISIONS 6) — distinct from the 401 reason banner's `.unauthorized`; the
/// feature authors no raw error string and there is no `APIError`→`ErrorDisplay` presenter here (the
/// reducer already collapsed every failure into the two `Validation` error cases).
///
/// Pure SwiftUI value code that compiles on the macOS host (the Swift/SPM host-build hazard) — no
/// iOS-only modifiers; the 401-bounce reason banner is the parent `OnboardingView`'s concern.
struct ConnectView: View {
  @Bindable var store: StoreOf<ConnectComponent>
  /// Focus for the single token field (Phase 12.4, TASK-003): drives submit-to-connect, tap-away
  /// dismissal, and keyboard cleanup after a complete paste. View-layer only — no reducer focus state
  /// (none is needed). `@FocusState` is cross-platform, so the file stays host-buildable.
  @FocusState private var tokenFieldFocused: Bool

  init(store: StoreOf<ConnectComponent>) {
    self.store = store
  }

  /// The inline error-row copy for the current validation state, `nil` when there is no error. Both
  /// error cases share the row structure and negative tint; only the copy differs (`.invalid` keeps its
  /// exact pre-18.3 rendering).
  private var errorLabel: String? {
    switch store.validation {
    case .invalid: ErrorDisplay.tokenRejected.label
    case .unreachable: ErrorDisplay.serverUnreachable.label
    case .idle, .validating: nil
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      // Header: a small, top-left soft-tinted tile + left-aligned title/subtitle (not a centered block).
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        Image(systemName: "heart.fill")
          .font(.system(size: Metrics.glyph))
          .foregroundStyle(.coachAccent)
          .frame(width: Metrics.tile, height: Metrics.tile)
          .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(.coachAccentSoft))

        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          Text("Let's connect you")
            .font(.coachText2xl)
            .foregroundStyle(.coachForeground)
          Text("Enter the access token from your coach to start syncing your training and recovery.")
            .font(.coachTextMd)
            .foregroundStyle(.coachForegroundMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      Spacer()

      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        Text("Access token")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)

        HStack(spacing: CoachSpacing.spaceSm) {
          TextField("Paste your token", text: $store.token)
            .font(.coachTextMd)
            .foregroundStyle(.coachForeground)
            .autocorrectionDisabled()
            .focused($tokenFieldFocused)
            // The keyboard's Go submits exactly when the Connect button would be enabled (validation gate);
            // when it isn't, it's a harmless no-op (no half-submit) (Phase 12.4, TASK-003).
            .submitLabel(.go)
            .onSubmit {
              guard store.canSubmit else { return }
              tokenFieldFocused = false
              store.send(.connectTapped)
            }

          // Paste affordance: a bordered pill with a clipboard glyph (the design). Reads the clipboard
          // in the view and feeds `.tokenPasted` — `UIPasteboard` stays confined to the view (DECISIONS
          // 4), `#if`-guarded so the reducer + host build stay clipboard-free.
          Button {
            #if canImport(UIKit)
              if let value = UIPasteboard.general.string {
                store.send(.tokenPasted(value))
                // A paste is a complete token entry — don't leave a stale keyboard hovering (TASK-003).
                tokenFieldFocused = false
              }
            #endif
          } label: {
            HStack(spacing: CoachSpacing.space2xs) {
              Image(systemName: "doc.on.clipboard")
              Text("Paste")
            }
            .font(.coachTextSm)
            .foregroundStyle(.coachAccent)
            .padding(.horizontal, CoachSpacing.spaceSm)
            .padding(.vertical, CoachSpacing.space2xs)
            .overlay(
              RoundedRectangle(cornerRadius: CoachRadius.pill)
                .stroke(.coachBorder, lineWidth: 1)
            )
          }
          .buttonStyle(.coachPressable)
        }
        .padding(CoachSpacing.spaceMd)
        .background(
          RoundedRectangle(cornerRadius: CoachRadius.sm)
            .fill(errorLabel != nil ? Color.coachNegativeSoft : .coachSurfaceSunken)
        )
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.sm)
            .stroke(errorLabel != nil ? Color.coachNegative : .coachBorder, lineWidth: 1)
        )

        if let errorLabel {
          HStack(alignment: .top, spacing: CoachSpacing.space2xs) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(errorLabel)
            Spacer(minLength: 0)
          }
          .font(.coachTextXs)
          .foregroundStyle(.coachNegative)
        }

        HStack(alignment: .top, spacing: CoachSpacing.space2xs) {
          Image(systemName: "info.circle")
          Text("This app is personal — there's no sign-up or password. Your token is provisioned by your coach.")
          Spacer(minLength: 0)
        }
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundSubtle)
        .padding(.top, CoachSpacing.space2xs)
      }

      Spacer()

      PrimaryButton("Connect", isLoading: store.validation == .validating) { store.send(.connectTapped) }
        .disabled(!store.canSubmit)
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
    // Tap-away dismissal: a tap on the empty chrome clears focus. Buttons and the TextField consume their
    // own hits first, so this only fires in the empty regions — the Paste button stays unaffected (TASK-003).
    // No `ScrollView` exists here (fixed VStack), so `.scrollDismissesKeyboard` has nothing to attach to
    // and is deliberately omitted (D2 / round-1 #2).
    .contentShape(Rectangle())
    .onTapGesture { tokenFieldFocused = false }
  }
}

/// Glyph/tile geometry — named constants, not inline literals (mirrors the `DesignSystem` primitives'
/// `private enum Metrics` convention). A small top-left tile (not the large centered block).
private enum Metrics {
  static let glyph: CGFloat = 26
  static let tile: CGFloat = 52
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

#Preview("Connect Unreachable") {
  ConnectView(
    store: Store(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .unreachable)) {
      ConnectComponent()
    }
  )
}
