/// Every canned sample fixture, named by its JSON resource basename.
///
/// `rawValue` is the file basename under `Resources/`, so `resourceName` maps a case to its file
/// mechanically and `allCases` lets tests/iterators cover the whole set.
public enum SampleScenario: String, CaseIterable, Sendable {
  case dailyBriefGreen = "daily_brief_green"
  case dailyBriefAmber = "daily_brief_amber"
  case dailyBriefRed = "daily_brief_red"
  case dailyBriefRestGIFlare = "daily_brief_rest_gi_flare"
  case dailyBriefRestIllness = "daily_brief_rest_illness"
  case dailyBriefRestKnee = "daily_brief_rest_knee"
  case dailyBriefNoFood = "daily_brief_no_food"
  case weeklyPlanDeload = "weekly_plan_deload"
  case profile
  case syncResponse = "sync_response"

  /// The JSON resource basename (without extension) under `Resources/`.
  public var resourceName: String { rawValue }
}
