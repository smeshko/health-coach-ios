import APIClient
import BriefRepository
import CoachCore
import CoachTestSupport
import Database
import Dependencies
import Foundation
import Testing
import WireModels

/// A recording brief-route stub built on the shared `APIClient.failing(overriding:)` factory
/// (Phase 11.6 — replaces the deleted per-target `StubAPIClient`). Records daily/weekly call counts
/// and last args via the shared `CallRecorder`; the brief routes serve a canned DTO or throw a canned
/// `APIError`, and every other route fails (the "must not be called here" contract).
struct BriefAPIStub {
  private let dailyRecorder = CallRecorder<Bool>() // captures the `refresh` arg
  private let weeklyRecorder = CallRecorder<(isoWeek: String?, refresh: Bool)>()
  private let dailyResult: Result<WireModels.DailyBrief, APIError>
  private let weeklyResult: Result<WireModels.WeeklyPlan, APIError>

  init(
    dailyResult: Result<WireModels.DailyBrief, APIError> = .failure(.unexpectedStatus(0)),
    weeklyResult: Result<WireModels.WeeklyPlan, APIError> = .failure(.unexpectedStatus(0))
  ) {
    self.dailyResult = dailyResult
    self.weeklyResult = weeklyResult
  }

  var dailyCallCount: Int { dailyRecorder.count }
  var weeklyCallCount: Int { weeklyRecorder.count }
  var lastDailyRefresh: Bool? { dailyRecorder.lastArgument }
  var lastWeeklyRefresh: Bool? { weeklyRecorder.lastArgument?.refresh }
  var lastWeeklyArg: String?? { weeklyRecorder.lastArgument.map(\.isoWeek) }

  func makeClient() -> APIClient {
    .failing(
      dailyBrief: { _, refresh in
        dailyRecorder.record(refresh)
        return try dailyResult.get()
      },
      weeklyBrief: { isoWeek, refresh in
        weeklyRecorder.record((isoWeek, refresh))
        return try weeklyResult.get()
      }
    )
  }
}

/// Run `work` with Europe/Sofia + a fixed `now`, the stub API client, and a migrated in-memory DB.
/// Shared by the daily + weekly cache-policy tests.
func runWithSofia<T>(
  now: Date,
  stub: BriefAPIStub,
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
func envelopeError(_ code: ErrorCode, _ status: Int) -> APIError {
  .envelope(code: code, message: "", detail: nil, status: status)
}

/// Assert `work` throws exactly the `expected` `BriefError`.
func expectBriefError(
  _ expected: BriefError,
  _ work: () async throws -> some Any,
  sourceLocation: SourceLocation = #_sourceLocation
) async {
  do {
    _ = try await work()
    Issue.record("expected BriefError.\(expected)", sourceLocation: sourceLocation)
  } catch let error as BriefError {
    #expect(error == expected, sourceLocation: sourceLocation)
  } catch {
    Issue.record("expected BriefError, got \(error)", sourceLocation: sourceLocation)
  }
}
