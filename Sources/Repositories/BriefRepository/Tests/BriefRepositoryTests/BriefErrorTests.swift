import DomainModels
import SampleData
import XCTest

@testable import BriefRepository

final class BriefErrorTests: XCTestCase {
  func test_briefError_isEquatable() {
    XCTAssertEqual(BriefError.syncRequired, BriefError.syncRequired)
    XCTAssertNotEqual(BriefError.syncRequired, BriefError.serverError)
  }

  func test_testValue_returnsSampleDomain() async throws {
    let daily = try await BriefRepository.testValue.dailyBrief(false)
    XCTAssertEqual(daily, try SampleData.dailyBrief(.dailyBriefGreen).domain)

    let weekly = try await BriefRepository.testValue.weeklyBrief(nil, false)
    XCTAssertEqual(weekly, try SampleData.weeklyPlan(.weeklyPlanDeload).domain)
  }
}
