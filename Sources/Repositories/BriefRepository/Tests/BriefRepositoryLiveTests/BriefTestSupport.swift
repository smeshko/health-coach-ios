import APIClient
import BriefRepository
import CoachCore
import Database
import Dependencies
import Foundation
import WireModels
import XCTest

/// Run `work` with Europe/Sofia + a fixed `now`, the stub API client, and a migrated in-memory DB.
/// Shared by the daily + weekly cache-policy tests.
func runWithSofia<T>(
  now: Date,
  stub: StubAPIClient,
  database: DatabaseClient,
  _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withDependencies {
    $0.useEuropeSofia()
    $0.date = .constant(now)
    $0.apiClient = stub.makeClient()
    $0.database = database
  } operation: {
    try await work()
  }
}

/// Build an envelope `APIError` with an empty message — shortens the mapping cases.
func envelopeError(_ code: WireEnum<ErrorCode>, _ status: Int) -> APIError {
  .envelope(code: code, message: "", detail: nil, status: status)
}

/// Assert `work` throws exactly the `expected` `BriefError`.
func expectBriefError(
  _ expected: BriefError,
  _ work: () async throws -> some Any,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await work()
    XCTFail("expected BriefError.\(expected)", file: file, line: line)
  } catch let error as BriefError {
    XCTAssertEqual(error, expected, file: file, line: line)
  } catch {
    XCTFail("expected BriefError, got \(error)", file: file, line: line)
  }
}
