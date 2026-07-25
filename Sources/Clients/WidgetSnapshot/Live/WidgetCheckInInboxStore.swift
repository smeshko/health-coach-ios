import CoachCore
import DomainModels
import Foundation
import WidgetSnapshotClient

/// The check-in INBOX file store (Phase 21.5): `checkin-inbox.json` next to the snapshot in the App
/// Group container — the pending `CheckIn`s the widget's "All clear" AppIntent appends (the extension
/// has no DB) and the app drains into GRDB on launch/foreground. Same discipline as the snapshot
/// file: atomic writes, corrupt/missing degrades to empty, `WidgetSnapshotCoding` wire format
/// (`CheckIn` self-codes its date as the Sofia `yyyy-MM-dd` day key). Entries are latest-wins per
/// Sofia day, enforced at append.
public struct WidgetCheckInInboxStore: Sendable {
  public let fileURL: URL

  public init(directoryURL: URL) {
    fileURL = directoryURL.appendingPathComponent("checkin-inbox.json")
  }

  /// The store over the App Group container — `nil` when the container is unavailable (mirror of
  /// `WidgetSnapshotStore.appGroupStore()`); callers degrade silently, never crash.
  public static func appGroupStore() -> WidgetCheckInInboxStore? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupID)
      .map(WidgetCheckInInboxStore.init(directoryURL:))
  }

  /// The pending check-ins; `[]` on a missing file OR undecodable bytes (degrade-don't-fail — the
  /// next append repairs it).
  public func read() -> [DomainModels.CheckIn] {
    guard let data = try? Data(contentsOf: fileURL) else { return [] }
    return (try? WidgetSnapshotCoding.makeDecoder().decode([DomainModels.CheckIn].self, from: data)) ?? []
  }

  /// Append latest-wins per Sofia day (the `CheckInRecord` upsert-by-date convention), atomically.
  public func append(_ checkIn: DomainModels.CheckIn) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let data = try WidgetSnapshotCoding.makeEncoder().encode(Self.appending(checkIn, to: read()))
    try data.write(to: fileURL, options: .atomic)
  }

  /// Remove the inbox after a completed drain. A missing file is a no-op, so a repeated drain never
  /// throws.
  public func clear() throws {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
    try FileManager.default.removeItem(at: fileURL)
  }

  /// The pure latest-wins merge (host-testable): drop any pending entry for the same Sofia day, then
  /// append the newcomer.
  public static func appending(
    _ checkIn: DomainModels.CheckIn,
    to pending: [DomainModels.CheckIn],
    calendar: Calendar = .europeSofia
  ) -> [DomainModels.CheckIn] {
    pending.filter { !calendar.isDate($0.date, inSameDayAs: checkIn.date) } + [checkIn]
  }
}
