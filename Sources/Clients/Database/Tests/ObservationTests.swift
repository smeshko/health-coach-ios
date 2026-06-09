import Database
import DatabaseLive
import Foundation
import GRDB
import PersistenceModels
import Testing

struct ObservationTests {
  private static let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_observe_emitsInitialThenOnChange() async throws {
    let day = Self.day
    let database = try DatabaseClient.makeInMemory()
    let stream = database.observe { db in try CheckInRecord.fetchCount(db) }
    var iterator = stream.makeAsyncIterator()

    // Initial value reflects the (empty) DB.
    let initial = await iterator.next()
    #expect(initial == 0)

    // A write that changes the result re-emits (awaited, not slept).
    try await database.write { db in
      try CheckInRecord(date: day, giSymptoms: false, kneePain: 0, illness: false).save(db)
    }
    let afterWrite = await iterator.next()
    #expect(afterWrite == 1)
  }

  @Test func test_observe_finishesOnCancellation() async throws {
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
