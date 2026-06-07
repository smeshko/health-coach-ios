import BriefRepository
import CoachCore
import DomainModels

// Placeholder — the weekly get-or-generate policy is implemented in TASK-003. Daily (TASK-002) does
// not exercise this path; the real per-ISO-week cache + sync-gate + mapping land next.
func weeklyPlanPolicy(isoWeek _: ISOWeek?, refresh _: Bool) async throws -> DomainModels.WeeklyPlan {
  throw BriefError.serverError
}
