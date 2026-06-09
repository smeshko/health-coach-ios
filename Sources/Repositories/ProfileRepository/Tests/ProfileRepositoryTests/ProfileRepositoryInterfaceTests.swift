import DomainModels
import SampleData
import Testing

@testable import ProfileRepository

struct ProfileRepositoryInterfaceTests {
  @Test func test_mock_profile_returnsCannedDomain() async throws {
    let result = try await ProfileRepository.mock(scenario: .profile).profile()
    try #expect(result == SampleData.profile().domain)
  }

  @Test func test_mock_zones_returnsCannedZones() async throws {
    let zones = try await ProfileRepository.mock(scenario: .profile).zones()
    try #expect(zones == SampleData.profile().domain.zones)
  }

  @Test func test_testValue_returnsCannedProfile() async throws {
    let result = try await ProfileRepository.testValue.profile()
    try #expect(result == SampleData.profile().domain)
  }

  @Test func test_mock_recomputeNotices_yieldsCannedNotice() async throws {
    let stream = ProfileRepository.mock(scenario: .profile).recomputeNotices()
    var received: RecomputeNotice?
    for await notice in stream {
      received = notice
      break
    }
    #expect(received == RecomputeNotice(week: "2026-W04"))
  }

  @Test func test_profileRepositoryError_isEquatable() {
    #expect(ProfileRepositoryError.fetchFailed(reason: "x") == .fetchFailed(reason: "x"))
    #expect(ProfileRepositoryError.fetchFailed(reason: "x") != .fetchFailed(reason: "y"))
  }
}
