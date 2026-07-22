import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The strength-test input screen (`Strength Input Screen.png`) — a due callout (when due), two titled
/// `NumericStepper` cards seeded from the last logged test, and a **Save strength test** primary button.
/// Pushed from the You tab; the parent pops it on `Delegate.saved`. The "Where this lands" mini-history
/// card + a Trends tab in the mockup are out of scope (epic decision).
public struct StrengthTestView: View {
  @Bindable var store: StoreOf<StrengthTestFeature>

  public init(store: StoreOf<StrengthTestFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          Text("Strength test")
            .font(.coachText2xl)
            .foregroundStyle(.coachForeground)
          Text("Two numbers. One honest set each.")
            .font(.coachTextMd)
            .foregroundStyle(.coachForegroundMuted)
        }

        switch store.loadState {
        case .loading:
          // Brief on a local read; an explicit state so a failed read can't masquerade as a saveable
          // empty test (review #1).
          HStack {
            Spacer()
            ProgressView().tint(.coachAccent)
            Spacer()
          }
          .padding(.vertical, CoachSpacing.spaceLg)

        case .failed:
          InsetCallout(
            icon: "exclamationmark.triangle",
            tone: .warning,
            headline: "Couldn't load your last test",
            content: "Check your connection to your data and try again."
          )
          SecondaryButton("Try again", icon: "arrow.clockwise") {
            store.send(.retryTapped)
          }

        case .loaded:
          if store.isDue {
            InsetCallout(
              icon: "dumbbell",
              headline: "It's been a week since your last test",
              content: "Log today's max — it keeps the trend honest"
            )
          }

          StrengthCard(
            title: "Max push-ups",
            value: Binding(get: { store.maxPushups }, set: { store.send(.pushupsChanged($0)) })
          )
          StrengthCard(
            title: "Max pull-ups",
            value: Binding(get: { store.maxPullups }, set: { store.send(.pullupsChanged($0)) })
          )

          if store.saveState == .failed {
            // The surfaced save failure (Phase 20.2) — paired with the `.error` haptic below. The Save
            // button stays live as the retry; an edit clears this back to `.idle` in the reducer.
            InsetCallout(
              icon: "exclamationmark.triangle",
              tone: .warning,
              headline: "Couldn't save your test",
              content: "Your numbers are still here — try saving again."
            )
          }

          PrimaryButton(
            "Save strength test",
            icon: "checkmark",
            isLoading: store.saveState == .saving
          ) {
            store.send(.saveTapped)
          }
          .padding(.top, CoachSpacing.spaceXs)
        }
      }
      .padding(.horizontal, CoachSpacing.spaceLg)
      .padding(.vertical, CoachSpacing.spaceMd)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.coachBackground)
    .onAppear { store.send(.onAppear) }
    // The save's success feedback — fires when the reducer flips `saveState` to `.saved`, before the
    // parent pops on `Delegate.saved` (the haptic-before-pop contract).
    .sensoryFeedback(.success, trigger: store.saveState == .saved)
    // The save-failure feedback (Phase 20.2) — fires when a failed save flips `saveState` to `.failed`,
    // alongside the error callout above the Save button.
    .sensoryFeedback(.error, trigger: store.saveState == .failed)
  }
}

/// A titled count card — the section title + a muted "max in one set" caption pill above a
/// `NumericStepper`, on a surface card. The card chrome lives here (not in the primitive).
private struct StrengthCard: View {
  let title: String
  @Binding var value: Int

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Spacer(minLength: CoachSpacing.spaceSm)
        Text("max in one set")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
          .padding(.horizontal, CoachSpacing.spaceSm)
          .padding(.vertical, CoachSpacing.space2xs)
          .background(Capsule().fill(.coachSurfaceSunken))
      }
      NumericStepper(value: $value)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
  }
}

#Preview {
  StrengthTestView(
    store: .init(
      initialState: .init(loadState: .loaded, maxPushups: 42, maxPullups: 11, isDue: true),
      reducer: StrengthTestFeature.init
    )
  )
}
