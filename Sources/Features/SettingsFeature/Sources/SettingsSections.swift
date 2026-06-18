import ComposableArchitecture
import DesignSystem
import DomainModels
import Foundation
import SwiftUI

/// The CONNECTION section — coach-connection state, last-sync time (only when there's a real timestamp),
/// the "provisioned by your coach" footnote, and a Re-connect affordance (the only connection action —
/// there is no account/logout). The design doesn't show an explicit re-connect control, but the epic AC
/// ("re-connecting is reachable") requires one. The masked-access-token row was dropped (review) — a
/// last-4 suffix carries no user value; and an empty "Last sync" is hidden rather than shown as a
/// "Never synced" placeholder.
struct ConnectionSection: View {
  let store: StoreOf<SettingsFeature>
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date
  @State private var reconnectTaps = 0

  var body: some View {
    Section {
      HStack {
        Text("Coach connection")
          .foregroundStyle(.coachForeground)
        Spacer(minLength: CoachSpacing.spaceSm)
        ConnectionStatusBadge(status: store.connection.status)
      }
      if let lastSyncAt = store.lastSync.lastSyncAt {
        SettingRow(title: "Last sync", value: formatLastSync(lastSyncAt, now: date.now, calendar: calendar))
      }
      Button {
        reconnectTaps += 1
        store.send(.reconnectTapped)
      } label: {
        Text("Re-connect")
          .foregroundStyle(.coachAccent)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.coachPressable)
      .sensoryFeedback(.selection, trigger: reconnectTaps)
    } header: {
      Text("Connection")
    } footer: {
      Text("Provisioned by your coach — no account, password or sign-out.")
    }
  }
}

/// The PROFILE · MANAGED BY COACH section — read-only coach-managed constants: age, the five HR zones,
/// resting-HR / HRV baselines (VO₂max omitted — not a /profile field, DECISIONS #6), and a quiet
/// recompute notice when present.
struct ProfileConstantsSection: View {
  let store: StoreOf<SettingsFeature>

  var body: some View {
    Section {
      if let age = store.constants.age {
        SettingRow(title: "Age", value: "\(age) years")
      }
      if let zones = store.constants.zones {
        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          Text("Heart-rate zones")
            .foregroundStyle(.coachForeground)
          HRZonesRow(zones: zones)
        }
        .padding(.vertical, CoachSpacing.space2xs)
      }
      if let rhr = store.constants.restingHrBpm {
        SettingRow(title: "Resting HR baseline", value: "\(rhr) bpm")
      }
      if let hrv = store.constants.hrvBaselineMs {
        SettingRow(title: "HRV baseline", value: "\(hrv) ms")
      }
      if let week = store.constants.recomputeNoticeWeek {
        Text("Constants recomputed (week \(week))")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundSubtle)
      }
    } header: {
      Text("Profile · Managed by coach")
    }
  }
}

/// The five HR zones as a colored bar + per-zone label and bpm range (the design's HR-zones row). Pure —
/// the ranges come from the passed-in `Zones`, never fetched here. (DesignSystem has no ZoneChip; this
/// renders inline against the shared `coachZ1…coachZ5` color tokens.)
struct HRZonesRow: View {
  let zones: DomainModels.Zones

  private struct ZoneEntry: Identifiable {
    let id: String
    let range: DomainModels.ZoneRange
    let color: Color
  }

  private var entries: [ZoneEntry] {
    [
      ZoneEntry(id: "Z1", range: zones.z1, color: .coachZ1),
      ZoneEntry(id: "Z2", range: zones.z2, color: .coachZ2),
      ZoneEntry(id: "Z3", range: zones.z3, color: .coachZ3),
      ZoneEntry(id: "Z4", range: zones.z4, color: .coachZ4),
      ZoneEntry(id: "Z5", range: zones.z5, color: .coachZ5),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
      HStack(spacing: 3) {
        ForEach(entries) { entry in
          Capsule().fill(entry.color).frame(height: 6)
        }
      }
      HStack(spacing: 3) {
        ForEach(entries) { entry in
          VStack(spacing: CoachSpacing.space2xs) {
            Text(entry.id)
              .foregroundStyle(.coachForeground)
            Text("\(entry.range.low)–\(entry.range.high)")
              .foregroundStyle(.coachForegroundSubtle)
          }
          .font(.coachText2xs)
          .frame(maxWidth: .infinity)
        }
      }
    }
  }
}

/// The STRENGTH section (Phase 10.4) — a single "Strength test" row that delegates up to push the
/// `StrengthTestFeature` input screen, with a due-dot when a new test is due. The due flag is parent-set
/// (`MainTabs`, the single deriver); this section never reads `StrengthTestRepository`.
struct StrengthTestSection: View {
  let store: StoreOf<SettingsFeature>
  @State private var taps = 0

  var body: some View {
    Section {
      Button {
        taps += 1
        store.send(.strengthTestRowTapped)
      } label: {
        HStack(spacing: CoachSpacing.spaceSm) {
          Text("Strength test")
            .foregroundStyle(.coachForeground)
          if store.strengthTestDue {
            Circle().fill(.coachAccent).frame(width: 8, height: 8)
          }
          Spacer(minLength: CoachSpacing.spaceSm)
          Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.coachPressable)
      .sensoryFeedback(.selection, trigger: taps)
    } header: {
      Text("Strength")
    }
  }
}

/// The REMINDERS section (Phase 10.3) — the "Good morning check-in" toggle bound to the **effective**
/// state (so a denied/revoked permission shows OFF, never a lying ON) + an "allow notifications in
/// Settings" hint when notifications are denied.
struct RemindersSection: View {
  let store: StoreOf<SettingsFeature>

  var body: some View {
    Section {
      Toggle(
        isOn: Binding(
          get: { store.remindersEffectivelyOn },
          set: { store.send(.remindersToggled($0)) }
        )
      ) {
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          Text("Good morning check-in")
            .foregroundStyle(.coachForeground)
          Text("A gentle nudge at 7:00 AM")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundSubtle)
        }
      }
      .tint(.coachAccent)
      .sensoryFeedback(.selection, trigger: store.remindersEffectivelyOn)

      if store.showEnableInSettingsHint {
        Button {
          store.send(.openNotificationSettingsTapped)
        } label: {
          HStack {
            Text("Allow notifications in Settings to get reminders")
              .foregroundStyle(.coachAccent)
            Spacer(minLength: CoachSpacing.spaceSm)
            Image(systemName: "arrow.up.right")
              .font(.coachTextSm)
              .foregroundStyle(.coachAccent)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.coachPressable)
      }
    } header: {
      Text("Reminders")
    }
  }
}

/// The connection status badge — a colored dot + label (green/Connected, muted/Not connected, —).
struct ConnectionStatusBadge: View {
  let status: SettingsFeature.ConnectionStatus

  var body: some View {
    switch status {
    case .connected:
      HStack(spacing: CoachSpacing.space2xs) {
        Circle().fill(Color.coachPositive).frame(width: 8, height: 8)
        Text("Connected").foregroundStyle(.coachPositive)
      }
    case .notConnected:
      HStack(spacing: CoachSpacing.space2xs) {
        Circle().fill(Color.coachForegroundMuted).frame(width: 8, height: 8)
        Text("Not connected").foregroundStyle(.coachForegroundMuted)
      }
    case .unknown:
      Text("—").foregroundStyle(.coachForegroundSubtle)
    }
  }
}

/// A plain title/value row (title left, muted value right), the recurring shape of the Settings rows.
struct SettingRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.coachForeground)
      Spacer(minLength: CoachSpacing.spaceSm)
      Text(value)
        .foregroundStyle(.coachForegroundMuted)
        .multilineTextAlignment(.trailing)
    }
  }
}

/// "Today, 9:38 AM" / "Jun 8, 9:38 AM" in the pinned Europe/Sofia frame (`en_US_POSIX` keeps it
/// deterministic for snapshots); "Never synced" when nil.
func formatLastSync(_ date: Date?, now: Date, calendar: Calendar) -> String {
  guard let date else { return "Never synced" }
  let formatter = DateFormatter()
  formatter.calendar = calendar
  formatter.timeZone = calendar.timeZone
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = calendar.isDate(date, inSameDayAs: now) ? "'Today,' h:mm a" : "MMM d, h:mm a"
  return formatter.string(from: date)
}
