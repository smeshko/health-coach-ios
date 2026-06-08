import APIClient
import Database
import DatabaseLive
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import ProfileRepository
import SampleData
import WireModels
import XCTest

@testable import ProfileRepositoryLive

final class ProfileRecomputeTests: XCTestCase {
  private func seedProfile(_ database: DatabaseClient, week: String?) async throws {
    var mutable = try SampleData.profile().domain
    mutable.meta.constantsRecomputedWeek = week
    let domain = mutable
    try await database.write { db in try ProfileRecord(domain: domain).save(db) }
  }

  private func dtoWithWeek(_ week: String?) throws -> ProfileResponse {
    var dto = try SampleData.profile().dto
    dto.meta.constantsRecomputedWeek = week
    return dto
  }

  /// The first notice off `repo.recomputeNotices()` (the stream is `.unbounded`-buffered, so an emit
  /// before iteration is delivered). Used after a sentinel emit so it always terminates.
  private func firstNotice(_ repo: ProfileRepository) async -> RecomputeNotice? {
    for await notice in repo.recomputeNotices() {
      return notice
    }
    return nil
  }

  func test_recompute_surfacedOnProfileAndStream() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedProfile(db, week: "2026-W01") // previously cached week
    let api = try StubProfileAPI(result: .success(dtoWithWeek("2026-W02"))) // a new recompute week
    let repo = ProfileRepository.live(recompute: RecomputeStream())

    let result = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await repo.refresh()
    }

    XCTAssertEqual(result.meta.constantsRecomputedWeek, "2026-W02", "the changed week rides on the Profile")
    let received = await firstNotice(repo)
    XCTAssertEqual(received, RecomputeNotice(week: "2026-W02"), "a notice is emitted on the change")
  }

  func test_recompute_sameWeek_noNotice() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedProfile(db, week: "2026-W02")
    let api = try StubProfileAPI(result: .success(dtoWithWeek("2026-W02"))) // unchanged week
    let repo = ProfileRepository.live(recompute: RecomputeStream())

    _ = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await repo.refresh()
    }

    // A refresh with the SAME week must not emit. Emit a sentinel afterwards: if the first stream
    // element is the sentinel (not "2026-W02"), the same-week refresh emitted nothing.
    await repo.noteRecompute("SENTINEL")
    let received = await firstNotice(repo)
    XCTAssertEqual(received?.week, "SENTINEL", "an unchanged week must not emit a notice")
  }

  func test_recompute_firstEver_noNotice() async throws {
    let db = try DatabaseClient.makeInMemory() // empty → first-ever fetch
    let api = try StubProfileAPI(result: .success(dtoWithWeek("2026-W02")))
    let repo = ProfileRepository.live(recompute: RecomputeStream())

    _ = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await repo.profile()
    }

    // The initial load is not a recompute — no notice. Sentinel proves it.
    await repo.noteRecompute("SENTINEL")
    let received = await firstNotice(repo)
    XCTAssertEqual(received?.week, "SENTINEL", "the first-ever fetch must not emit a notice")
  }

  func test_zones_returnsFetchedZones() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))
    let repo = ProfileRepository.live(recompute: RecomputeStream())

    let zones = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await repo.zones()
    }

    XCTAssertEqual(zones, fixture.domain.zones, "zones() exposes the five HR zone bpm ranges")
  }

  func test_noteRecompute_emitsOnStream() async throws {
    let repo = ProfileRepository.live(recompute: RecomputeStream())
    await repo.noteRecompute("2026-W05")
    let received = await firstNotice(repo)
    XCTAssertEqual(received, RecomputeNotice(week: "2026-W05"))
  }
}
