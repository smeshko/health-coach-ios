import DomainModels
import SampleData
import Testing

@testable import BriefRepository

struct BriefErrorTests {
  @Test func test_briefError_isEquatable() {
    #expect(BriefError.syncRequired == BriefError.syncRequired)
    #expect(BriefError.syncRequired != BriefError.serverError)
  }

  @Test func test_testValue_returnsSampleDomain() async throws {
    let daily = try await BriefRepository.testValue.dailyBrief(false)
    try #expect(daily == SampleData.dailyBrief(.dailyBriefGreen).domain)

    let weekly = try await BriefRepository.testValue.weeklyBrief(nil, false)
    try #expect(weekly == SampleData.weeklyPlan(.weeklyPlanDeload).domain)
  }
}
