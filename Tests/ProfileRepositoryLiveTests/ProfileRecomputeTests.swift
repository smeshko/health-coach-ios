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

  func test_recompute_surfacedOnProfileAndStream() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedProfile(db, week: "2026-W01") // previously cached week
    var dto = try SampleData.profile().dto
    dto.meta.constantsRecomputedWeek = "2026-W02" // a new recompute week
    let api = StubProfileAPI(result: .success(dto))

    // One repo instance so refresh() and recomputeNotices() share the same stream.
    let repo = ProfileRepository.liveValue

    let result = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await repo.refresh()
    }

    // The week rides on the returned Profile...
    XCTAssertEqual(result.meta.constantsRecomputedWeek, "2026-W02")
    // ...and a notice is emitted on the stream (buffered, .unbounded).
    var received: RecomputeNotice?
    for await notice in repo.recomputeNotices() {
      received = notice
      break
    }
    XCTAssertEqual(received, RecomputeNotice(week: "2026-W02"))
  }

  func test_zones_returnsFetchedZones() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))

    let zones = try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = db
    } operation: {
      try await ProfileRepository.liveValue.zones()
    }

    XCTAssertEqual(zones, fixture.domain.zones, "zones() exposes the five HR zone bpm ranges")
  }

  func test_noteRecompute_emitsOnStream() async throws {
    let repo = ProfileRepository.liveValue
    await repo.noteRecompute("2026-W05")

    var received: RecomputeNotice?
    for await notice in repo.recomputeNotices() {
      received = notice
      break
    }
    XCTAssertEqual(received, RecomputeNotice(week: "2026-W05"))
  }
}
