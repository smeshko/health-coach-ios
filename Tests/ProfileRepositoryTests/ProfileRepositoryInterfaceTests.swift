import DomainModels
import SampleData
import XCTest

@testable import ProfileRepository

final class ProfileRepositoryInterfaceTests: XCTestCase {
  func test_mock_profile_returnsCannedDomain() async throws {
    let result = try await ProfileRepository.mock(scenario: .profile).profile()
    XCTAssertEqual(result, try SampleData.profile().domain)
  }

  func test_mock_zones_returnsCannedZones() async throws {
    let zones = try await ProfileRepository.mock(scenario: .profile).zones()
    XCTAssertEqual(zones, try SampleData.profile().domain.zones)
  }

  func test_testValue_returnsCannedProfile() async throws {
    let result = try await ProfileRepository.testValue.profile()
    XCTAssertEqual(result, try SampleData.profile().domain)
  }

  func test_mock_recomputeNotices_yieldsCannedNotice() async throws {
    let stream = ProfileRepository.mock(scenario: .profile).recomputeNotices()
    var received: RecomputeNotice?
    for await notice in stream {
      received = notice
      break
    }
    XCTAssertEqual(received, RecomputeNotice(week: "2026-W04"))
  }

  func test_profileRepositoryError_isEquatable() {
    XCTAssertEqual(ProfileRepositoryError.fetchFailed(reason: "x"), .fetchFailed(reason: "x"))
    XCTAssertNotEqual(ProfileRepositoryError.fetchFailed(reason: "x"), .fetchFailed(reason: "y"))
  }
}
