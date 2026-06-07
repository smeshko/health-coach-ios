import Dependencies
import SampleData
import SyncRepository
import WireModels
import XCTest

@testable import SyncRepositoryLive

final class MockTests: XCTestCase {
  func test_mock_success_returnsCannedResult_noLiveDeps() async throws {
    // No live deps are injected — the mock must not resolve HealthKit/APIClient/Database. If it did,
    // resolving an unimplemented dependency here would fail the test.
    let result = try await SyncRepository.mock(scenario: .success).sync()

    let expected = try syncResult(SampleData.syncResponse())
    XCTAssertEqual(result, expected, "the mock returns the SampleData sync_response fixture as a SyncResult")
  }
}
