import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The degraded-permissions screen (`Wrap Degraded*` designs): shown when some HealthKit signals read
/// empty (DECISIONS #2). A single-signal banner names the most-impactful missing row, a per-row list
/// pairs each `PrimingRow` with an "On" / "Not shared" pill, and a non-blocking "Open Health settings"
/// + "Continue" let the user proceed anyway (degraded is never a hard block — epic AC-2). All copy
/// comes through the `DesignSystem` label boundary. Pure SwiftUI; host-safe.
struct DegradedPermissionsView: View {
  let store: StoreOf<HealthKitPriming>
  let summary: HealthKitPriming.DegradedSummary

  init(store: StoreOf<HealthKitPriming>, summary: HealthKitPriming.DegradedSummary) {
    self.store = store
    self.summary = summary
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
          VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
            Text("A few signals are missing")
              .font(.coachText2xl)
              .foregroundStyle(.coachForeground)
            Text("Your brief still works — it just gets sharper as more data flows in.")
              .font(.coachTextMd)
              .foregroundStyle(.coachForegroundMuted)
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(spacing: CoachSpacing.spaceMd) {
            ForEach(PrimingRow.allCases, id: \.self) { row in
              DegradedSignalRow(title: row.rowLabel.title, isMissing: summary.missing.contains(row))
            }
          }
          .padding(CoachSpacing.spaceLg)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(.coachSurface))
        }
        .padding(CoachSpacing.spaceLg)
      }

      VStack(spacing: CoachSpacing.spaceSm) {
        PrimaryButton("Open Health settings", icon: "gear") { store.send(.openHealthSettingsTapped) }
        SecondaryButton("Continue") { store.send(.continueTapped) }
      }
      .padding(.horizontal, CoachSpacing.spaceLg)
      .padding(.bottom, CoachSpacing.spaceLg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}

/// One degraded-screen row: the signal title with a trailing On / Not-shared status pill. A struct (not
/// a `body`-building computed property) per the project's SwiftUI decomposition rule.
private struct DegradedSignalRow: View {
  let title: String
  let isMissing: Bool

  var body: some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      Text(title)
        .font(.coachTextMd)
        .foregroundStyle(isMissing ? .coachForegroundMuted : .coachForeground)
      Spacer(minLength: 0)
      if isMissing {
        Pill("Not shared", tone: .warning, leading: .icon("minus"))
      } else {
        Pill("On", tone: .positive, leading: .icon("checkmark"))
      }
    }
  }
}

#Preview("Degraded Permissions") {
  DegradedPermissionsView(
    store: Store(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    },
    summary: HealthKitPriming.DegradedSummary(missing: [.sleep, .vo2Max], bannerSignal: .sleep)
  )
}
