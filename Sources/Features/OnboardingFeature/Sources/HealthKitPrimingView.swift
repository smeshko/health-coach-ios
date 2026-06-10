import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The HealthKit priming screen (`Wrap HealthKit*` designs): a `NavigationStack` with the standard
/// large title, a left-aligned explainer that lists each Apple-Health signal group **before** the
/// unskippable system sheet, and the "Connect Apple Health" CTA → `connectTapped` (which spins in place
/// while the sheet / degraded probe is in flight). All copy comes through the `DesignSystem` label
/// boundary (`PrimingRow.groupLabel`) — no raw machine key. Pure SwiftUI on `DesignSystem` tokens;
/// compiles on the macOS host (the one UIKit-only nav modifier is `#if os(iOS)`-guarded).
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
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
            Text(
              "Here's what each signal does before the system sheet appears — "
                + "nothing leaves your phone without your say."
            )
            .font(.coachTextMd)
            .foregroundStyle(.coachForegroundMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
              ForEach(PrimingRow.primingGroups, id: \.self) { group in
                PrimingSignalRow(label: group.groupLabel)
              }
            }
            .padding(CoachSpacing.spaceLg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(.coachSurface))
          }
          .padding(CoachSpacing.spaceLg)
        }

        PrimaryButton("Connect Apple Health", icon: "heart.fill", isLoading: isWorking) {
          store.send(.connectTapped)
        }
        .padding(.horizontal, CoachSpacing.spaceLg)
        .padding(.bottom, CoachSpacing.spaceLg)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(.coachBackground)
      .navigationTitle("Connect Apple Health")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
      #endif
    }
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
