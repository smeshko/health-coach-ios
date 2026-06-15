import DomainModels
import Foundation
import GRDB

/// The athlete's selected daily workout — a flat record keyed by `date` (the Europe/Sofia day, upsert
/// latest-wins) whose `body` blob is the serialized `SessionBlock`. Persisted **by value** (DECISIONS D4):
/// `SessionBlock` has no stable id, so on hydrate the stored block is matched back to a candidate by
/// `Equatable`. The next Sofia day's key is empty, so the pick resets automatically (no cleanup needed —
/// stale rows are simply never read), mirroring `CheckInRecord`/`DailyBriefRecord`.
public struct SessionSelectionRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "sessionSelection"

  public var date: Date
  public var body: Data

  public init(date: Date, body: Data) {
    self.date = date
    self.body = body
  }

  /// Serialize a selected block into a record keyed by `date` (the full value lives in `body`). Uses the
  /// same `DomainBodyCoder` the brief/plan records use — one blob-coding convention.
  public init(date: Date, block: DomainModels.SessionBlock) throws {
    try self.init(date: date, body: DomainBodyCoder.encode(block))
  }

  /// Reconstruct the selected block from the serialized `body` (lossless).
  public func selectedBlock() throws -> DomainModels.SessionBlock {
    try DomainBodyCoder.decode(DomainModels.SessionBlock.self, from: body)
  }
}
