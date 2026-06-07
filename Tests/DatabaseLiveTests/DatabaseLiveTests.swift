import Database
import DatabaseLive
import GRDB
import XCTest

final class DatabaseLiveTests: XCTestCase {
  func test_makeInMemory_returnsUsableQueue() async throws {
    let database = try DatabaseClient.makeInMemory()
    let one = try await database.read { db in try Int.fetchOne(db, sql: "SELECT 1") }
    XCTAssertEqual(one, 1)
  }
}
