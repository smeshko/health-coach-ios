import Database
import DatabaseLive
import GRDB
import Testing

struct DatabaseLiveTests {
  @Test func test_makeInMemory_returnsUsableQueue() async throws {
    let database = try DatabaseClient.makeInMemory()
    let one = try await database.read { db in try Int.fetchOne(db, sql: "SELECT 1") }
    #expect(one == 1)
  }
}
