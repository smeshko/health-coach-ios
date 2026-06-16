import Testing

@testable import NotificationClient

/// Smoke coverage of the boundary value types: they are `public`, `Sendable`, `Equatable`, and build
/// from both trigger kinds. The recording-behaviour tests land in TASK-002.
struct NotificationModelsTests {
  @Test func test_notificationRequest_isEquatable_acrossTriggerKinds() {
    let daily = NotificationRequest(
      id: "r1",
      title: "Morning check-in",
      body: "How are you feeling?",
      trigger: .calendar(dateComponents: NotificationDateComponents(hour: 7, minute: 30), repeats: true)
    )
    let dailyAgain = NotificationRequest(
      id: "r1",
      title: "Morning check-in",
      body: "How are you feeling?",
      trigger: .calendar(dateComponents: NotificationDateComponents(hour: 7, minute: 30), repeats: true)
    )
    let interval = NotificationRequest(
      id: "r1",
      title: "Morning check-in",
      body: "How are you feeling?",
      trigger: .timeInterval(seconds: 60, repeats: false)
    )

    #expect(daily == dailyAgain, "equal fields + equal trigger compare equal")
    #expect(daily != interval, "differing trigger kinds compare unequal")
  }

  @Test func test_notificationRequest_differingID_comparesUnequal() {
    let trigger = NotificationTrigger.calendar(
      dateComponents: NotificationDateComponents(weekday: 2, hour: 18, minute: 0),
      repeats: true
    )
    let reqA = NotificationRequest(id: "a", title: "T", body: "B", trigger: trigger)
    let reqB = NotificationRequest(id: "b", title: "T", body: "B", trigger: trigger)
    #expect(reqA != reqB, "differing ids compare unequal")
  }

  @Test func test_notificationDateComponents_defaultsAreNil() {
    let empty = NotificationDateComponents()
    #expect(empty.weekday == nil)
    #expect(empty.hour == nil)
    #expect(empty.minute == nil)
  }

  @Test func test_authorizationStatus_isEquatable() {
    #expect(NotificationAuthorizationStatus.authorized == .authorized)
    #expect(NotificationAuthorizationStatus.denied != .authorized)
  }
}
