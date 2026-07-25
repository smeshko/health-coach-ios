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
      read: { WidgetSnapshotStore.appGroupStore()?.read() }
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
