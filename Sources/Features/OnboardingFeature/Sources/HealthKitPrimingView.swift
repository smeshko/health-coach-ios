import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The HealthKit priming screen (`Wrap HealthKit*` designs): a left-aligned explainer that lists each
/// Apple-Health signal group **before** the unskippable system sheet, the MyFitnessPal "read, not
/// entered" callout, and the "Connect Apple Health" CTA → `connectTapped`. All copy comes through the
/// `DesignSystem` label boundary (`PrimingRow.groupLabel`) — no raw machine key. Pure SwiftUI on
/// `DesignSystem` tokens; compiles on the macOS host (no UIKit-only / HealthKit API).
struct HealthKitPrimingView: View {
  let store: StoreOf<HealthKitPriming>

  init(store: StoreOf<HealthKitPriming>) {
    self.store = store
  }

  /// True while the system sheet / degraded probe is in flight — spins the CTA, blocks a re-tap.
  private var isWorking: Bool {
    switch store.phase {
    case .authorizing, .checking: true
    default: false
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
          VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
            Text("Connect Apple Health")
              .font(.coachText2xl)
              .foregroundStyle(.coachForeground)
            Text(
              "Here's what each signal does before the system sheet appears — "
                + "nothing leaves your phone without your say."
            )
            .font(.coachTextMd)
            .foregroundStyle(.coachForegroundMuted)
            .fixedSize(horizontal: false, vertical: true)
          }

          VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
            ForEach(PrimingRow.primingGroups, id: \.self) { group in
              PrimingSignalRow(label: group.groupLabel)
            }
          }
          .padding(CoachSpacing.spaceLg)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(.coachSurface))

          Banner(
            icon: "info.circle",
            tone: .warning,
            title: nil,
            message: "Food is logged in MyFitnessPal, which writes to Apple Health. "
              + "This app only reads it — there's no food, weight or workout entry here."
          )
        }
        .padding(CoachSpacing.spaceLg)
      }

      PrimaryButton("Connect Apple Health", icon: "heart.fill") { store.send(.connectTapped) }
        .disabled(isWorking)
        .overlay {
          if isWorking {
            ProgressView().tint(.coachOnAccent)
          }
        }
        .padding(.horizontal, CoachSpacing.spaceLg)
        .padding(.bottom, CoachSpacing.spaceLg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// One priming-screen group: a soft-tinted icon tile + the group title and its "why it matters" line.
/// A struct (not a `body`-building computed property) per the project's SwiftUI decomposition rule.
private struct PrimingSignalRow: View {
  let label: HealthSignalLabel

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
      Image(systemName: label.iconName)
        .font(.system(size: Metrics.glyph))
        .foregroundStyle(.coachAccent)
        .frame(width: Metrics.tile, height: Metrics.tile)
        .background(RoundedRectangle(cornerRadius: CoachRadius.sm).fill(.coachAccentSoft))

      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(label.title)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Text(label.subtitle)
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
  }
}

/// Icon-tile geometry — named constants (the `DesignSystem` primitives' `private enum Metrics` convention).
private enum Metrics {
  static let glyph: CGFloat = 18
  static let tile: CGFloat = 40
}

#Preview("HealthKit Priming") {
  HealthKitPrimingView(
    store: Store(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    }
  )
}
