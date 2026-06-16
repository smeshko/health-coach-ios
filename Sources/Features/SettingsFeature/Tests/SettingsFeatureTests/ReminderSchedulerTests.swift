import NotificationClient
import Testing

@testable import SettingsFeature

/// Pure logic tests for `ReminderScheduler`: the two stable IDs + the daily/weekly request builders, and
/// that `enable`/`disable` route to the right `NotificationClient` calls (via the 10.1 recording value).
@MainActor
struct ReminderSchedulerTests {
  @Test func test_reminderIDs_areStableAndDistinct() {
    #expect(ReminderID.morningCheckIn == "reminder.morning-checkin")
    #expect(ReminderID.weeklyStrengthTest == "reminder.weekly-strength-test")
    #expect(ReminderID.morningCheckIn != ReminderID.weeklyStrengthTest)
    #expect(ReminderID.all == [ReminderID.morningCheckIn, ReminderID.weeklyStrengthTest])
  }

  @Test func test_morningRequest_isDaily0700() {
    let request = ReminderScheduler().morningCheckInRequest()
    #expect(request.id == ReminderID.morningCheckIn)
    guard case let .calendar(components, repeats) = request.trigger else {
      Issue.record("expected a calendar trigger")
      return
    }
    #expect(components.hour == 7)
    #expect(components.minute == 0)
    #expect(components.weekday == nil, "no weekday ⇒ daily cadence")
    #expect(repeats)
  }

  @Test func test_weeklyRequest_isWeekly() {
    let request = ReminderScheduler().weeklyStrengthTestRequest()
    #expect(request.id == ReminderID.weeklyStrengthTest)
    guard case let .calendar(components, repeats) = request.trigger else {
      Issue.record("expected a calendar trigger")
      return
    }
    #expect(components.weekday == 2, "a weekday ⇒ weekly cadence (Monday)")
    #expect(components.hour == 7)
    #expect(components.minute == 0)
    #expect(repeats)
  }

  @Test func test_enable_schedulesBothRequests() async throws {
    let (client, recorder) = NotificationClient.recording()
    try await ReminderScheduler().enable(client)

    let scheduled = await recorder.scheduledRequests().map(\.id)
    #expect(Set(scheduled) == Set(ReminderID.all), "enable schedules exactly the two stable IDs")
  }

  @Test func test_disable_cancelsBothIDs() async {
    let (client, recorder) = NotificationClient.recording()
    // Seed both as pending, then disable.
    try? await ReminderScheduler().enable(client)
    await ReminderScheduler().disable(client)

    #expect(await recorder.pendingIdentifiers() == [], "both reminders are cancelled")
    #expect(Set(await recorder.cancelledIdentifiers()) == Set(ReminderID.all))
  }

  @Test func test_enableTwice_doesNotStack() async throws {
    let (client, recorder) = NotificationClient.recording()
    try await ReminderScheduler().enable(client)
    try await ReminderScheduler().enable(client)

    // Re-scheduling the same IDs replaces (id-keyed) — still exactly two pending.
    #expect(await recorder.pendingIdentifiers().count == 2)
  }
}
