import Foundation
import HealthKitClient
import HealthKitClientLive
import XCTest

/// Host-compilable smoke for the live target. HealthKit *is* importable on macOS, so on the host the
/// real `#if canImport(HealthKit)` branch runs — but `HKHealthStore.isHealthDataAvailable()` returns
/// `false` on the Mac, so `liveValue` reports `.healthDataUnavailable` and `deltaSamples` short-
/// circuits to `.empty`. The real on-device auth/delta behaviour is the TASK-005 manual checklist.
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
