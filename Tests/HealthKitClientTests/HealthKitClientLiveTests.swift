import Foundation
import HealthKitClient
import HealthKitClientLive
import XCTest

/// Host-compilable smoke for the live target. HealthKit is iOS-only, so on the macOS host this
/// exercises the `#else` branch (`liveValue` reports `.healthDataUnavailable`). The real iOS path is
/// the TASK-005 manual checklist.
final class HealthKitClientLiveTests: XCTestCase {
  func test_liveValue_onHost_reportsHealthDataUnavailable() async throws {
    let client = HealthKitClient.liveValue
    XCTAssertFalse(client.isHealthDataAvailable())
    let status = client.authorizationStatus()
    XCTAssertEqual(status.count, HealthDataCategory.allCases.count)
    XCTAssertTrue(status.values.allSatisfy { $0 == .healthDataUnavailable })
    let delta = try await client.deltaSamples(.distantPast)
    XCTAssertEqual(delta, .empty)
  }
}
