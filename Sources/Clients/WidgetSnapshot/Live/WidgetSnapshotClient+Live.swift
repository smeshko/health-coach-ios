import CoachCore
import Dependencies
import DomainModels
import Foundation
import LogClient
import WidgetSnapshotClient
#if canImport(WidgetKit)
  import WidgetKit
#endif

extension WidgetSnapshotClient: DependencyKey {
  /// The live mirror: merge-write into the App Group store, then reload the widget timelines. All
  /// writes hop through one `WidgetSnapshotSerializer` actor so concurrent `update*` calls (the
  /// sibling section writers 21.2/21.4/21.5 add) are serialized — the read→merge→write cycle is not
  /// atomic on its own and two interleaved writers would silently drop a section (PLAN Risks).
  /// Every failure logs and drops — the brief path never fails because of the mirror (DECISIONS D6).
  public static var liveValue: WidgetSnapshotClient {
    let serializer = WidgetSnapshotSerializer()
    return WidgetSnapshotClient(
      updateDailyBrief: { brief in await serializer.updateDailyBrief(brief) },
      updateWeeklyPlan: { plan in await serializer.updateWeeklyPlan(plan) },
      updateSelectedSession: { block, day in await serializer.updateSelectedSession(block, day: day) },
      read: { WidgetSnapshotStore.appGroupStore()?.read() },
      updateCheckIn: { state in await serializer.updateCheckIn(state) },
      logCheckInFromWidget: { checkIn in await serializer.logCheckInFromWidget(checkIn) },
      pendingCheckIns: { WidgetCheckInInboxStore.appGroupStore()?.read() ?? [] },
      clearPendingCheckIns: { await serializer.clearPendingCheckIns() }
    )
  }
}

/// Serializes all snapshot-file mutations within the app process (validation round-1 #3). The pure
/// merge stays a free function on `WidgetSnapshotStore`; this actor only owns the ordering.
private actor WidgetSnapshotSerializer {
  func updateDailyBrief(_ brief: DomainModels.DailyBrief) {
    @Dependency(\.log) var log
    @Dependency(\.date) var date

    guard let store = WidgetSnapshotStore.appGroupStore() else {
      // No container (missing entitlement / host build) — the mirror is a no-op, never an error.
      log.notice("Widget snapshot skipped — App Group container unavailable", category: .app)
      return
    }
    do {
      try store.mergeDailyBrief(brief, generatedAt: date.now)
      reloadTimelines()
      // The epic's "observable via log" acceptance hook: one line per mirror write.
      log.info(
        "Widget snapshot updated",
        category: .app,
        metadata: ["sofiaDay": sofiaDayKey(brief.date)]
      )
    } catch {
      log.notice(
        "Widget snapshot write failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  func updateWeeklyPlan(_ plan: DomainModels.WeeklyPlan) {
    @Dependency(\.log) var log
    @Dependency(\.date) var date

    guard let store = WidgetSnapshotStore.appGroupStore() else {
      log.notice("Widget snapshot skipped — App Group container unavailable", category: .app)
      return
    }
    do {
      try store.mergeWeeklyPlan(plan, generatedAt: date.now)
      reloadTimelines()
      log.info(
        "Widget snapshot updated",
        category: .app,
        metadata: ["isoWeek": plan.isoWeek]
      )
    } catch {
      log.notice(
        "Widget snapshot write failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  /// The Phase 21.2 selection hook: merge the athlete's pick into `daily.selectedSession`. A declined
  /// merge (no same-Sofia-day daily section to attach to) is a silent no-op, same as a missing
  /// container — the selection save path never fails because of the mirror.
  func updateSelectedSession(_ block: DomainModels.SessionBlock, day: Date) {
    @Dependency(\.log) var log
    @Dependency(\.date) var date

    guard let store = WidgetSnapshotStore.appGroupStore() else {
      log.notice("Widget snapshot skipped — App Group container unavailable", category: .app)
      return
    }
    do {
      guard try store.mergeSelectedSession(block, day: day, generatedAt: date.now) else { return }
      reloadTimelines()
      log.info(
        "Widget snapshot selection updated",
        category: .app,
        metadata: ["sofiaDay": sofiaDayKey(day)]
      )
    } catch {
      log.notice(
        "Widget snapshot selection write failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  /// The app-side check-in mirror (Phase 21.5) — fired by `CheckInRepository.save` after each upsert.
  func updateCheckIn(_ state: WidgetCheckInState) {
    @Dependency(\.log) var log
    @Dependency(\.date) var date

    guard let store = WidgetSnapshotStore.appGroupStore() else {
      log.notice("Widget snapshot skipped — App Group container unavailable", category: .app)
      return
    }
    do {
      try store.mergeCheckIn(state, generatedAt: date.now)
      reloadTimelines()
      log.info(
        "Widget snapshot check-in updated",
        category: .app,
        metadata: ["sofiaDay": sofiaDayKey(state.date), "logged": "\(state.logged)"]
      )
    } catch {
      log.notice(
        "Widget snapshot check-in write failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  /// The widget "All clear" AppIntent's write (Phase 21.5), running in the EXTENSION process: append
  /// the pending check-in to the inbox, flip the snapshot to logged (`source: .widget`), reload.
  /// NOTE the 21.1 cross-process story loosens here by design: the extension now WRITES on an
  /// explicit tap (still atomic write-then-rename, so neither process ever observes a torn file); a
  /// same-instant app-side merge racing it remains an accepted single-owner risk.
  func logCheckInFromWidget(_ checkIn: DomainModels.CheckIn) {
    @Dependency(\.log) var log
    @Dependency(\.date) var date

    guard
      let inbox = WidgetCheckInInboxStore.appGroupStore(),
      let store = WidgetSnapshotStore.appGroupStore()
    else {
      log.notice("Widget check-in skipped — App Group container unavailable", category: .app)
      return
    }
    do {
      try inbox.append(checkIn)
      try store.mergeCheckIn(
        WidgetCheckInState(date: checkIn.date, logged: true, source: .widget),
        generatedAt: date.now
      )
      reloadTimelines()
      log.info(
        "Widget all-clear check-in appended to inbox",
        category: .app,
        metadata: ["sofiaDay": sofiaDayKey(checkIn.date)]
      )
    } catch {
      log.notice(
        "Widget check-in inbox write failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  /// Remove the inbox after the app-side drain persisted (or superseded) every pending entry.
  func clearPendingCheckIns() {
    @Dependency(\.log) var log

    guard let inbox = WidgetCheckInInboxStore.appGroupStore() else { return }
    do {
      try inbox.clear()
    } catch {
      log.notice(
        "Widget check-in inbox clear failed — dropping",
        category: .app,
        metadata: ["error": String(describing: error)]
      )
    }
  }

  private func reloadTimelines() {
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadAllTimelines()
    #endif
  }

  /// The brief's Sofia calendar day as `yyyy-MM-dd` for the log line.
  private func sofiaDayKey(_ date: Date) -> String {
    let components = Calendar.europeSofia.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0
    )
  }
}
