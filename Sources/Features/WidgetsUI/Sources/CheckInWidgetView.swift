import AppIntents
import DesignSystem
import Foundation
import SwiftUI
import WidgetSnapshotClient

/// The check-in nudge widget's view (Phase 21.5, systemSmall): unlogged → the interactive
/// "All clear" button (an in-extension AppIntent, no app launch) over a "Symptoms…" hint — the rest
/// of the widget surface deep-links into the app's check-in flow via the WidgetKit wrapper's
/// `widgetURL`; logged → a confirmation instead of the button. Logged-ness runs through the shared
/// Sofia staleness helper, so yesterday's logged state renders as today's unlogged nudge (the
/// rollover reset). Plain SwiftUI (not WidgetKit-guarded) so the snapshot target renders it.
public struct CheckInWidgetView: View {
  let checkIn: WidgetCheckInState?
  let now: Date

  public init(checkIn: WidgetCheckInState?, now: Date) {
    self.checkIn = checkIn
    self.now = now
  }

  /// Logged only when the state is for `now`'s Sofia day — the shared helper, never re-derived math.
  private var isLoggedToday: Bool {
    guard let checkIn else { return false }
    return checkIn.logged && checkIn.isCurrent(at: now)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
      Text("CHECK-IN")
        .font(.coachText2xs)
        .tracking(1)
        .foregroundStyle(.coachForegroundSubtle)
      Spacer(minLength: 0)
      if isLoggedToday {
        Image(systemName: "checkmark.circle.fill")
          .font(.coachText2xl)
          .foregroundStyle(.coachPositive)
        Text("Logged")
          .font(.coachTextMd)
          .foregroundStyle(.coachForeground)
        Text("See you tomorrow")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
      } else {
        Text("How do you feel?")
          .font(.coachTextSm)
          .foregroundStyle(.coachForeground)
        Button(intent: CheckInAllClearIntent()) {
          Text("All clear")
            .font(.coachTextSm)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.coachAccent)
        Text("Symptoms…")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(CoachSpacing.spaceMd)
  }
}
