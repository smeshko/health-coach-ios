import NotificationClient

extension NotificationAuthorizationStatus {
  /// The single granted-ness predicate for reminders: `.authorized` and `.provisional` (the OS's quiet-
  /// deliver state) permit scheduling; `.denied`/`.notDetermined` don't.
  var isGranted: Bool {
    switch self {
    case .authorized, .provisional: true
    case .denied, .notDetermined: false
    }
  }
}

/// The pure reminder-identity + request-builder helper (Phase 10.3). Owns the two **stable**
/// notification identifiers and the daily/weekly `NotificationRequest`s, and turns "reminders on/off"
/// into concrete `NotificationClient` calls — so the reducer (TASK-002) calls one seam and all
/// identity/trigger logic stays testable on the host. Framework-free: it uses only 10.1's pure value
/// types (no `UserNotifications`, no Foundation `DateComponents`).
enum ReminderID {
  /// Reused on every reschedule so a re-schedule **replaces** the pending request (UNUserNotificationCenter
  /// keys pending requests by identifier — no stacking).
  static let morningCheckIn = "reminder.morning-checkin"
  /// Doubles as the deep-link route key the app maps to the Phase 10.4 StrengthTestFeature screen.
  static let weeklyStrengthTest = "reminder.weekly-strength-test"
  static let all = [morningCheckIn, weeklyStrengthTest]
}

/// The fixed reminder times (single source — DECISIONS #2). Monday 07:00 weekly is an assumption (PRD/
/// design don't specify the weekday); these are constants so product can tune them later.
enum ReminderTime {
  static let morningHour = 7
  static let morningMinute = 0
  static let weeklyWeekday = 2 // Monday, Gregorian (Sunday = 1)
  static let weeklyHour = 7
  static let weeklyMinute = 0
}

/// Builds the requests and schedules/cancels them over the injected `NotificationClient`.
struct ReminderScheduler {
  /// The daily morning-nudge request. Daily cadence is encoded by populating only `hour`/`minute` (no
  /// `weekday`). The post-Epic-8.5 check-in is a gating cover over Today, so this nudge's job is to get
  /// the user to open the app and clear the cover before today's brief appears (fire-and-open).
  func morningCheckInRequest() -> NotificationRequest {
    NotificationRequest(
      id: ReminderID.morningCheckIn,
      title: "Good morning",
      body: "Open the app to check in",
      trigger: .calendar(
        dateComponents: NotificationDateComponents(
          hour: ReminderTime.morningHour,
          minute: ReminderTime.morningMinute
        ),
        repeats: true
      )
    )
  }

  /// The weekly strength-test nudge. The populated `weekday` makes it weekly (PRD §7.3 ~weekly cadence).
  /// Its stable `id` is the deep-link route key for the Phase 10.4 StrengthTestFeature screen.
  func weeklyStrengthTestRequest() -> NotificationRequest {
    NotificationRequest(
      id: ReminderID.weeklyStrengthTest,
      title: "Strength check",
      body: "It's been a week — log your strength test",
      trigger: .calendar(
        dateComponents: NotificationDateComponents(
          weekday: ReminderTime.weeklyWeekday,
          hour: ReminderTime.weeklyHour,
          minute: ReminderTime.weeklyMinute
        ),
        repeats: true
      )
    )
  }

  /// Schedule both reminders (two `schedule(_:)` calls — 10.1's `schedule` takes one request). Throws if
  /// either schedule fails; the reducer treats a throw like the denied path (TASK-002).
  func enable(_ client: NotificationClient) async throws {
    try await client.schedule(morningCheckInRequest())
    try await client.schedule(weeklyStrengthTestRequest())
  }

  /// Cancel both reminders by their stable IDs (one non-throwing `cancel(_:)`).
  func disable(_ client: NotificationClient) async {
    await client.cancel(ReminderID.all)
  }
}
