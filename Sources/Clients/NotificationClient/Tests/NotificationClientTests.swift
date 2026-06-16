import Testing

@testable import NotificationClient

/// The recording test value records `schedule`/`cancel` calls in process — **without importing or
/// touching `UserNotifications`** (the epic's AC-2). Scheduling is id-keyed so a re-schedule overwrites
/// (mirroring iOS `UNUserNotificationCenter.add(_:)` and the PRD §7.3 weekly-overwrite rule).
struct NotificationClientTests {
  private func request(
    id: String,
    body: String = "B",
    trigger: NotificationTrigger = .calendar(
      dateComponents: NotificationDateComponents(hour: 7, minute: 30),
      repeats: true
    )
  ) -> NotificationRequest {
    NotificationRequest(id: id, title: "T", body: body, trigger: trigger)
  }

  @Test func test_scheduleRecordsRequest() async throws {
    let (client, recorder) = NotificationClient.recording()
    let req = request(id: "r1")

    try await client.schedule(req)

    #expect(await client.pendingIdentifiers() == ["r1"])
    #expect(await recorder.scheduledRequests() == [req])
  }

  @Test func test_rescheduleSameIDOverwrites() async throws {
    let (client, recorder) = NotificationClient.recording()

    try await client.schedule(request(id: "r1", body: "first"))
    let second = request(
      id: "r1",
      body: "second",
      trigger: .timeInterval(seconds: 60, repeats: false)
    )
    try await client.schedule(second)

    let pending = await client.pendingIdentifiers()
    #expect(pending == ["r1"], "re-scheduling the same id leaves one entry, not two")
    #expect(await recorder.scheduledRequests() == [second], "the stored request is the latest")
  }

  @Test func test_cancelRemovesByID() async throws {
    let (client, recorder) = NotificationClient.recording()
    try await client.schedule(request(id: "r1"))
    try await client.schedule(request(id: "r2"))

    await client.cancel(["r1"])

    #expect(await client.pendingIdentifiers() == ["r2"])
    #expect(await recorder.cancelledIdentifiers() == ["r1"])
  }

  @Test func test_cancelUnknownIDIsNoop() async {
    let (client, recorder) = NotificationClient.recording()

    await client.cancel(["nope"])

    #expect(await client.pendingIdentifiers() == [])
    #expect(await recorder.cancelledIdentifiers() == ["nope"], "cancel is recorded even for unknown ids")
  }

  @Test func test_recordingAuthorization_isAuthorized() async throws {
    let (client, _) = NotificationClient.recording()
    #expect(try await client.requestAuthorization() == .authorized)
    #expect(await client.authorizationStatus() == .authorized)
  }
}
