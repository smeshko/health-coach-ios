import ComposableArchitecture
import DesignSystem
import Foundation
import SwiftUI

/// The morning check-in (PRD §7.2) restyled to `1 · Daily Check-in.png`: a "DAILY CHECK-IN" eyebrow (the
/// mockup's "How are you today?" title + subtitle are dropped — they doubled up under the screen's
/// "Today" header), a card with two Yes/No rows (helper copy) + the knee-pain segment stepper & severity
/// badge, a "Save & build today's brief" button, and a "Last saved <time>" footer. `kneePain` edits route
/// through `kneePainChanged` (clamped) — out-of-range is impossible (DECISIONS #2). The footer time is
/// formatted in the Europe/Sofia frame so snapshots stay deterministic.
///
/// Rendered both standalone in `.checkInRequired` (the gate) and under `ready` by `TodayView`.
struct CheckInSection: View {
  @Bindable var store: StoreOf<CheckInComponent>
  @Dependency(\.calendar) var calendar

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      Text("DAILY CHECK-IN")
        .font(.coachText2xs)
        .tracking(0.4)
        .foregroundStyle(.coachForegroundMuted)

      VStack(spacing: CoachSpacing.spaceMd) {
        CheckInQuestionRow(
          title: "Any gut-flare signs today?",
          helper: "Bloating, cramps or urgency",
          isOn: Binding(get: { store.giSymptoms }, set: { store.send(.giSymptomsToggled($0)) })
        )
        Rectangle().fill(.coachBorder).frame(height: 1)
        CheckInQuestionRow(
          title: "Feeling ill or feverish?",
          helper: "Sore throat, chills, fever",
          isOn: Binding(get: { store.illness }, set: { store.send(.illnessToggled($0)) })
        )
        Rectangle().fill(.coachBorder).frame(height: 1)
        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
              Text("Knee pain")
                .font(.coachTextLg)
                .foregroundStyle(.coachForeground)
              Text("0 = none · 10 = worst")
                .font(.coachTextSm)
                .foregroundStyle(.coachForegroundMuted)
            }
            Spacer(minLength: CoachSpacing.spaceSm)
            Pill(PainSeverity.badge(for: store.kneePain), tone: .warning)
          }
          SegmentStepper(
            value: Binding(get: { store.kneePain }, set: { store.send(.kneePainChanged($0)) })
          )
        }
      }
      .padding(CoachSpacing.spaceMd)
      .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(.coachSurface))

      VStack(spacing: CoachSpacing.spaceSm) {
        PrimaryButton("Save & build today's brief", isLoading: store.saveStatus == .saving) {
          store.send(.saveTapped)
        }
        // The footer shows a precise clock time only for a save made this session (`lastSavedAt`); a
        // check-in loaded from earlier today has only a day-key, so it shows day-relative copy instead.
        if let savedAt = store.lastSavedAt {
          CheckInFooter(text: "Last saved \(savedTime(savedAt)) · tap any answer to edit")
        } else if store.existing != nil {
          CheckInFooter(text: "Saved earlier today · tap any answer to edit")
        }
      }
    }
    .task { await store.send(.task).finish() }
  }

  /// "7:02 AM" in the Europe/Sofia frame (the pinned `\.calendar`); `en_US_POSIX` keeps it deterministic.
  private func savedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
  }
}

/// The check-in card's "✓ <message>" footer (`1 · Daily Check-in.png`) — a checkmark + a single muted,
/// centered line. The message varies by save state (precise time for a same-session save, day-relative
/// for a loaded check-in); the chrome is identical, so it lives in one struct.
private struct CheckInFooter: View {
  let text: String

  var body: some View {
    HStack(spacing: CoachSpacing.space2xs) {
      Image(systemName: "checkmark.circle")
      Text(text)
    }
    .font(.coachTextXs)
    .foregroundStyle(.coachForegroundSubtle)
    .frame(maxWidth: .infinity)
  }
}

/// One Yes/No question row in the check-in card — a title + helper line on the left, a `YesNoToggle` on
/// the trailing edge (`1 · Daily Check-in.png`).
private struct CheckInQuestionRow: View {
  let title: String
  let helper: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(title)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Text(helper)
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
      Spacer(minLength: CoachSpacing.spaceSm)
      YesNoToggle(isOn: $isOn)
    }
  }
}
