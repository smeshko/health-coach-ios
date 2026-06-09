import Dependencies
import SampleData
import SyncRepository
import Testing
import WireModels

@testable import SyncRepositoryLive

struct MockTests {
  @Test func test_mock_success_returnsCannedResult_noLiveDeps() async throws {
    // No live deps are injected — the mock must not resolve HealthKit/APIClient/Database. If it did,
    // resolving an unimplemented dependency here would fail the test.
    let result = try await SyncRepository.mock(scenario: .success).sync()

    let expected = try syncResult(SampleData.syncResponse())
    #expect(result == expected, "the mock returns the SampleData sync_response fixture as a SyncResult")
  }
}
