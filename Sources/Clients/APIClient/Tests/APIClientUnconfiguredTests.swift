import APIClient
import APIClientLive
import Foundation
import Testing
import WireModels

/// CR-1: when no base URL resolves, the client must be loud at first use — every call throws a
/// clear configuration `APIError.transport` (never a silent localhost target, never a launch
/// trap) and the session-event stream finishes immediately instead of hanging its consumer.
struct APIClientUnconfiguredTests {
  private let expectedError = APIError.transport(
    "API base URL not configured — set API_BASE_URL in the CoachApp build settings"
  )

  @Test func test_probe_throwsConfigurationTransportError() async {
    await #expect(throws: expectedError) {
      _ = try await APIClient.unconfigured.probe()
    }
  }

  @Test func test_sync_throwsConfigurationTransportError() async {
    await #expect(throws: expectedError) {
      _ = try await APIClient.unconfigured.sync(SyncRequest())
    }
  }

  @Test func test_dailyBrief_throwsConfigurationTransportError() async {
    await #expect(throws: expectedError) {
      _ = try await APIClient.unconfigured.dailyBrief(nil, false)
    }
  }

  @Test func test_weeklyBrief_throwsConfigurationTransportError() async {
    await #expect(throws: expectedError) {
      _ = try await APIClient.unconfigured.weeklyBrief(nil, false)
    }
  }

  @Test func test_profile_throwsConfigurationTransportError() async {
    await #expect(throws: expectedError) {
      _ = try await APIClient.unconfigured.profile()
    }
  }

  @Test func test_sessionEvents_finishesImmediately_withoutEmitting() async {
    var events: [SessionEvent] = []
    // The loop terminating at all is the "no hang" assertion — a never-finishing stream would
    // deadlock this test rather than fail it.
    for await event in APIClient.unconfigured.sessionEvents() {
      events.append(event)
    }
    #expect(events.isEmpty)
  }
}
