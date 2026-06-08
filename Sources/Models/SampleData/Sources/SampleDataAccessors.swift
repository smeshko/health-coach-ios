import DomainModels
import Foundation
import WireDomainMapping
import WireModels

/// Errors raised by the sample-data accessors.
public enum SampleDataError: Error, Equatable {
  case resourceNotFound(String)
}

public extension SampleData {
  /// The raw canned JSON for a scenario, loaded from the target bundle.
  static func jsonData(for scenario: SampleScenario) throws -> Data {
    guard let url = Bundle.module.url(forResource: scenario.resourceName, withExtension: "json") else {
      throw SampleDataError.resourceNotFound(scenario.resourceName)
    }
    return try Data(contentsOf: url)
  }

  /// A daily-brief scenario as both its decoded DTO and its mapped domain value.
  static func dailyBrief(
    _ scenario: SampleScenario
  ) throws -> (dto: WireModels.DailyBrief, domain: DomainModels.DailyBrief) {
    let dto = try WireCoder.decoder.decode(WireModels.DailyBrief.self, from: jsonData(for: scenario))
    return try (dto, domainDailyBrief(dto))
  }

  /// A weekly-plan scenario as both its decoded DTO and its mapped domain value.
  static func weeklyPlan(
    _ scenario: SampleScenario
  ) throws -> (dto: WireModels.WeeklyPlan, domain: DomainModels.WeeklyPlan) {
    let dto = try WireCoder.decoder.decode(WireModels.WeeklyPlan.self, from: jsonData(for: scenario))
    return try (dto, domainWeeklyPlan(dto))
  }

  /// The profile fixture as both its decoded DTO and its mapped domain value.
  static func profile() throws -> (dto: WireModels.ProfileResponse, domain: DomainModels.Profile) {
    let dto = try WireCoder.decoder.decode(WireModels.ProfileResponse.self, from: jsonData(for: .profile))
    return (dto, domainProfile(dto))
  }

  /// The sync-response fixture (no domain peer in this phase).
  static func syncResponse() throws -> WireModels.SyncResponse {
    try WireCoder.decoder.decode(WireModels.SyncResponse.self, from: jsonData(for: .syncResponse))
  }

  // MARK: - Preview / mock convenience factories

  //
  // Force-try is intentional here: these vend canned, in-bundle fixtures for SwiftUI previews and
  // mock dependencies — a load/decode failure is a build-time authoring error, surfaced loudly.
  // swiftlint:disable force_try

  static var dailyBriefGreen: DomainModels.DailyBrief { try! dailyBrief(.dailyBriefGreen).domain }
  static var dailyBriefRest: DomainModels.DailyBrief { try! dailyBrief(.dailyBriefRestGIFlare).domain }
  static var dailyBriefNoFood: DomainModels.DailyBrief { try! dailyBrief(.dailyBriefNoFood).domain }
  static var weeklyPlanDeload: DomainModels.WeeklyPlan { try! weeklyPlan(.weeklyPlanDeload).domain }
  static var sampleProfile: DomainModels.Profile { try! profile().domain }

  // swiftlint:enable force_try
}
