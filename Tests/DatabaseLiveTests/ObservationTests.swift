import Database
import DatabaseLive
import GRDB
import PersistenceModels
import XCTest

final class ObservationTests: XCTestCase {
  private static let day = Date(timeIntervalSince1970: 1_780_000_000)

  func test_observe_emitsInitialThenOnChange() async throws {
    let day = Self.day
    let database = try DatabaseClient.makeInMemory()
    let stream = database.observe { db in try CheckInRecord.fetchCount(db) }
    var iterator = stream.makeAsyncIterator()

    // Initial value reflects the (empty) DB.
    let initial = await iterator.next()
    XCTAssertEqual(initial, 0)

    // A write that changes the result re-emits (awaited, not slept).
    try await database.write { db in
      try CheckInRecord(date: day, giSymptoms: false, kneePain: 0, illness: false).save(db)
    }
    let afterWrite = await iterator.next()
    XCTAssertEqual(afterWrite, 1)
  }

  func test_observe_finishesOnCancellation() async throws {
    let database = try DatabaseClient.makeInMemory()
    let stream = database.observe { db in try CheckInRecord.fetchCount(db) }

    let task = Task {
      for await _ in stream {
        // drain
      }
    }
    // Cancelling the consuming Task must finish the stream (and cancel the GRDB observation) — if it
    // leaked, `await task.value` would hang and the test would time out.
    task.cancel()
    await task.value
  }
}
