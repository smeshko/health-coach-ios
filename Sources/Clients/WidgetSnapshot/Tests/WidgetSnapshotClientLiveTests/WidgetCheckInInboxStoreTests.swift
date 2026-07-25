import CoachCore
import DomainModels
import Foundation
import Testing
import WidgetSnapshotClient
import WidgetSnapshotClientLive

/// `WidgetCheckInInboxStore` file semantics (Phase 21.5): the append/read/clear round-trip, the
/// latest-wins-per-Sofia-day append, and missing/corrupt degradation. All against a fresh temp
/// directory — never the real App Group container.
@Suite("WidgetCheckInInboxStore")
struct WidgetCheckInInboxStoreTests {
  private func makeStore() -> WidgetCheckInInboxStore {
    WidgetCheckInInboxStore(
      directoryURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    )
  }

  /// A Sofia-midnight day key — what the drain normalizes to anyway, and what `CheckIn`'s
  /// `yyyy-MM-dd` wire coding round-trips losslessly.
  private func sofiaDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    // Force-unwrap: fixed valid components against the fixed europeSofia calendar.
    return Calendar.europeSofia.date(from: components)!
  }

  private func allClear(date: Date) -> DomainModels.CheckIn {
    DomainModels.CheckIn(date: date, giSymptoms: false, kneePain: 0, illness: false)
  }

  // MARK: - Round-trip

  @Test func test_appendThenRead_roundTripsEntries() throws {
    let store = makeStore()
    let first = allClear(date: sofiaDay(2026, 7, 23))
    let second = allClear(date: sofiaDay(2026, 7, 24))

    try store.append(first)
    try store.append(second)

    #expect(store.read() == [first, second])
  }

  @Test func test_clear_removesFile_andRepeatedClearNeverThrows() throws {
    let store = makeStore()
    try store.append(allClear(date: sofiaDay(2026, 7, 24)))

    try store.clear()
    #expect(store.read() == [])
    // A second clear over the now-missing file must be a silent no-op (re-drain safety).
    try store.clear()
  }

  @Test func test_read_missingFile_returnsEmpty() {
    #expect(makeStore().read() == [])
  }

  @Test func test_read_corruptFile_returnsEmpty() throws {
    let store = makeStore()
    try store.append(allClear(date: sofiaDay(2026, 7, 24)))
    try Data("not json {{{".utf8).write(to: store.fileURL)

    #expect(store.read() == [])
  }

  // MARK: - Latest-wins per Sofia day

  @Test func test_append_sameSofiaDayTwice_keepsLatestOnly() throws {
    let store = makeStore()
    let day = sofiaDay(2026, 7, 24)
    let first = allClear(date: day)
    let second = DomainModels.CheckIn(date: day, giSymptoms: true, kneePain: 2, illness: false)

    try store.append(first)
    try store.append(second)

    #expect(store.read() == [second], "same-day entries must collapse latest-wins (CheckInRecord convention)")
  }

  @Test func test_appending_pure_intraDayInstantsCollide_crossDayDoNot() {
    let day = sofiaDay(2026, 7, 24)
    // 09:00 Sofia the same day — a different instant, the same Sofia day key.
    let sameDayLater = DomainModels.CheckIn(
      date: day.addingTimeInterval(9 * 3600), giSymptoms: false, kneePain: 1, illness: false
    )
    let nextDay = allClear(date: sofiaDay(2026, 7, 25))

    let collapsed = WidgetCheckInInboxStore.appending(sameDayLater, to: [allClear(date: day)])
    #expect(collapsed == [sameDayLater])

    let kept = WidgetCheckInInboxStore.appending(nextDay, to: [allClear(date: day)])
    #expect(kept == [allClear(date: day), nextDay])
  }
}
