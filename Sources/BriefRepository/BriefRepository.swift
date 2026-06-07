import CoachCore
import Dependencies
import DomainModels
import SampleData

/// The daily-brief / weekly-plan repository — the single clean seam features get-or-generate briefs
/// through (ARCHITECTURE §7). A `Sendable` struct of **concrete** typed `@Sendable` closures
/// (swift-dependencies stored closures can't be generic, §6.1); `.live` (network + GRDB) lives in
/// `BriefRepositoryLive`, `.mock(scenario:)` in this interface target (DECISIONS #3).
///
/// `weeklyBrief` takes `CoachCore.ISOWeek?` — `nil` means the current Europe/Sofia ISO week (the
/// server resolves it). The `ISOWeek` → `YYYY-Www` string the API / cache key need is formatted in
/// `BriefRepositoryLive` (DECISIONS #4); `ISOWeek` itself ships no `wireString`.
public struct BriefRepository: Sendable {
  /// Get-or-generate today's (Europe/Sofia) daily brief. `refresh == true` forces regeneration.
  public var dailyBrief: @Sendable (_ refresh: Bool) async throws -> DomainModels.DailyBrief
  /// Get-or-generate the weekly plan for `isoWeek` (`nil` = current Sofia week). `refresh` forces
  /// regeneration.
  public var weeklyBrief: @Sendable (_ isoWeek: ISOWeek?, _ refresh: Bool) async throws -> DomainModels.WeeklyPlan

  public init(
    dailyBrief: @escaping @Sendable (_ refresh: Bool) async throws -> DomainModels.DailyBrief,
    weeklyBrief: @escaping @Sendable (_ isoWeek: ISOWeek?, _ refresh: Bool) async throws -> DomainModels.WeeklyPlan
  ) {
    self.dailyBrief = dailyBrief
    self.weeklyBrief = weeklyBrief
  }
}

extension BriefRepository: TestDependencyKey {
  /// Serves the default `SampleData` fixtures (green daily / deload weekly) with no live dependency.
  public static var testValue: BriefRepository {
    BriefRepository(
      dailyBrief: { _ in try SampleData.dailyBrief(.dailyBriefGreen).domain },
      weeklyBrief: { _, _ in try SampleData.weeklyPlan(.weeklyPlanDeload).domain }
    )
  }

  /// Same fixtures as `testValue` — previews run on the default sample brief/plan.
  public static var previewValue: BriefRepository {
    testValue
  }
}

public extension DependencyValues {
  var briefRepository: BriefRepository {
    get { self[BriefRepository.self] }
    set { self[BriefRepository.self] = newValue }
  }
}
