import BriefRepository
import Dependencies

extension BriefRepository: DependencyKey {
  /// The network + GRDB live value. The composition root installs it (optionally wrapped by the
  /// 4.1 `routed(dev:)` toggle).
  public static var liveValue: BriefRepository { .live }

  public static let live = BriefRepository(
    dailyBrief: { refresh in
      try await dailyBriefPolicy(refresh: refresh)
    },
    // Weekly get-or-generate is wired in TASK-003 (WeeklyPlanPolicy); daily is this task's focus.
    weeklyBrief: { isoWeek, refresh in
      try await weeklyPlanPolicy(isoWeek: isoWeek, refresh: refresh)
    }
  )
}
