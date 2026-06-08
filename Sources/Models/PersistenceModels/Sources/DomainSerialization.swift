// This file is intentionally long: it holds the hand-written Codable conformances for every
// DomainModels value type in one place (cross-module synthesis is unavailable), so the per-property
// boilerplate adds up well past the default file-length limit.
// swiftlint:disable file_length

import DomainModels
import Foundation

// Codable conformances for the DomainModels value types, declared HERE in PersistenceModels so that
// DomainModels itself stays Codable-free (a hard architectural invariant). These conformances let
// PersistenceModels JSON-serialize a composite domain value into a record's `body: Data` column
// losslessly. Cross-module Codable synthesis does not work, so every conformance is hand-written:
// structs provide explicit `init(from:)` / `encode(to:)`; closed enums use the `CaseStringCodable`
// protocol default below; the semantic enums (with a `.unknown(String)` case) use a keyed
// `kind` + `raw` discriminator.

// MARK: - Closed enums

/// Codable default for closed, associated-value-free enums: encodes each case as its case-name
/// string (e.g. `"easyRun"`) and decodes by matching `String(describing:)` against `allCases`.
protocol CaseStringCodable: Codable, CaseIterable {}

extension CaseStringCodable {
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let match = Self.allCases.first(where: { String(describing: $0) == raw }) else {
      throw try DecodingError.dataCorruptedError(
        in: decoder.singleValueContainer(),
        debugDescription: "Unknown \(Self.self) raw value: \(raw)"
      )
    }
    self = match
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(String(describing: self))
  }
}

extension DomainModels.Card: CaseStringCodable {}
extension DomainModels.Zone: CaseStringCodable {}
extension DomainModels.ReadinessBand: CaseStringCodable {}
extension DomainModels.DayType: CaseStringCodable {}
extension DomainModels.Intensity: CaseStringCodable {}
extension DomainModels.NarrativeType: CaseStringCodable {}
extension DomainModels.Tier: CaseStringCodable {}
extension DomainModels.Weekday: CaseStringCodable {}

// MARK: - Semantic enums (known cases + `.unknown(String)`)

extension DomainModels.Flag: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case raw
  }

  // The known cases, paired with their case-name `kind` discriminator.
  private static let knownCases: [(kind: String, value: DomainModels.Flag)] = [
    ("impact", .impact),
    ("needsGreenKnee", .needsGreenKnee),
    ("lowImpact", .lowImpact),
    ("preferLowImpact", .preferLowImpact),
    ("kneeAmberCap", .kneeAmberCap),
    ("appendToEasy", .appendToEasy),
    ("effortBased", .effortBased),
    ("autoRegDowngrade", .autoRegDowngrade),
    ("bigRecoveryCost", .bigRecoveryCost),
    ("prehabFoot", .prehabFoot),
    ("prehabGlute", .prehabGlute),
    ("qualityDay", .qualityDay),
  ]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(String.self, forKey: .kind)
    if kind == "unknown" {
      self = try .unknown(container.decode(String.self, forKey: .raw))
      return
    }
    guard let match = Self.knownCases.first(where: { $0.kind == kind })?.value else {
      throw DecodingError.dataCorruptedError(
        forKey: CodingKeys.kind,
        in: container,
        debugDescription: "Unknown Flag kind: \(kind)"
      )
    }
    self = match
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if case let .unknown(raw) = self {
      try container.encode("unknown", forKey: .kind)
      try container.encode(raw, forKey: .raw)
    } else {
      try container.encode(String(describing: self), forKey: .kind)
    }
  }
}

extension DomainModels.SafetyReason: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case raw
  }

  // The known cases, paired with their case-name `kind` discriminator.
  private static let knownCases: [(kind: String, value: DomainModels.SafetyReason)] = [
    ("giFlare", .giFlare),
    ("illness", .illness),
    ("kneePainHigh", .kneePainHigh),
    ("sleepBelow4h", .sleepBelow4h),
    ("rhrSpike", .rhrSpike),
    ("hrvCrash", .hrvCrash),
  ]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(String.self, forKey: .kind)
    if kind == "unknown" {
      self = try .unknown(container.decode(String.self, forKey: .raw))
      return
    }
    guard let match = Self.knownCases.first(where: { $0.kind == kind })?.value else {
      throw DecodingError.dataCorruptedError(
        forKey: CodingKeys.kind,
        in: container,
        debugDescription: "Unknown SafetyReason kind: \(kind)"
      )
    }
    self = match
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if case let .unknown(raw) = self {
      try container.encode("unknown", forKey: .kind)
      try container.encode(raw, forKey: .raw)
    } else {
      try container.encode(String(describing: self), forKey: .kind)
    }
  }
}

extension DomainModels.PenaltyFactor: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case raw
  }

  // The known cases, paired with their case-name `kind` discriminator.
  private static let knownCases: [(kind: String, value: DomainModels.PenaltyFactor)] = [
    ("sleepBelow7h", .sleepBelow7h),
    ("sleepBelow5h", .sleepBelow5h),
    ("hrvBelowBaseline", .hrvBelowBaseline),
    ("rhrAboveBaseline", .rhrAboveBaseline),
    ("yesterdayHardDay", .yesterdayHardDay),
  ]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(String.self, forKey: .kind)
    if kind == "unknown" {
      self = try .unknown(container.decode(String.self, forKey: .raw))
      return
    }
    guard let match = Self.knownCases.first(where: { $0.kind == kind })?.value else {
      throw DecodingError.dataCorruptedError(
        forKey: CodingKeys.kind,
        in: container,
        debugDescription: "Unknown PenaltyFactor kind: \(kind)"
      )
    }
    self = match
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if case let .unknown(raw) = self {
      try container.encode("unknown", forKey: .kind)
      try container.encode(raw, forKey: .raw)
    } else {
      try container.encode(String(describing: self), forKey: .kind)
    }
  }
}

// MARK: - Structs

extension DomainModels.DailyBrief: Codable {
  private enum CodingKeys: String, CodingKey {
    case date
    case readiness
    case safetyGate
    case session
    case alternatives
    case skipOk
    case macroFocus
    case intakeYesterday
    case generatedAt
    case cached
    case constitutionVersion
    case narrative
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      date: container.decode(Date.self, forKey: .date),
      readiness: container.decode(Readiness.self, forKey: .readiness),
      safetyGate: container.decode(SafetyGate.self, forKey: .safetyGate),
      session: container.decode(SessionBlock.self, forKey: .session),
      alternatives: container.decode([SessionBlock].self, forKey: .alternatives),
      skipOk: container.decode(Bool.self, forKey: .skipOk),
      macroFocus: container.decode(MacroFocus.self, forKey: .macroFocus),
      intakeYesterday: container.decodeIfPresent(IntakeSummary.self, forKey: .intakeYesterday),
      generatedAt: container.decode(Date.self, forKey: .generatedAt),
      cached: container.decode(Bool.self, forKey: .cached),
      constitutionVersion: container.decodeIfPresent(String.self, forKey: .constitutionVersion),
      narrative: container.decode([NarrativeSection].self, forKey: .narrative)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(date, forKey: .date)
    try container.encode(readiness, forKey: .readiness)
    try container.encode(safetyGate, forKey: .safetyGate)
    try container.encode(session, forKey: .session)
    try container.encode(alternatives, forKey: .alternatives)
    try container.encode(skipOk, forKey: .skipOk)
    try container.encode(macroFocus, forKey: .macroFocus)
    try container.encodeIfPresent(intakeYesterday, forKey: .intakeYesterday)
    try container.encode(generatedAt, forKey: .generatedAt)
    try container.encode(cached, forKey: .cached)
    try container.encodeIfPresent(constitutionVersion, forKey: .constitutionVersion)
    try container.encode(narrative, forKey: .narrative)
  }
}

extension DomainModels.WeeklyPlan: Codable {
  private enum CodingKeys: String, CodingKey {
    case isoWeek
    case weekStart
    case budgets
    case core
    case extras
    case targets
    case nutrition
    case constantsRecomputed
    case generatedAt
    case cached
    case narrative
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      isoWeek: container.decode(String.self, forKey: .isoWeek),
      weekStart: container.decode(Date.self, forKey: .weekStart),
      budgets: container.decode(WeeklyBudgets.self, forKey: .budgets),
      core: container.decode([PlannedSession].self, forKey: .core),
      extras: container.decode([PlannedSession].self, forKey: .extras),
      targets: container.decode(WeeklyTargets.self, forKey: .targets),
      nutrition: container.decode(WeeklyNutrition.self, forKey: .nutrition),
      constantsRecomputed: container.decode(Bool.self, forKey: .constantsRecomputed),
      generatedAt: container.decode(Date.self, forKey: .generatedAt),
      cached: container.decode(Bool.self, forKey: .cached),
      narrative: container.decode([NarrativeSection].self, forKey: .narrative)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(isoWeek, forKey: .isoWeek)
    try container.encode(weekStart, forKey: .weekStart)
    try container.encode(budgets, forKey: .budgets)
    try container.encode(core, forKey: .core)
    try container.encode(extras, forKey: .extras)
    try container.encode(targets, forKey: .targets)
    try container.encode(nutrition, forKey: .nutrition)
    try container.encode(constantsRecomputed, forKey: .constantsRecomputed)
    try container.encode(generatedAt, forKey: .generatedAt)
    try container.encode(cached, forKey: .cached)
    try container.encode(narrative, forKey: .narrative)
  }
}

extension DomainModels.Readiness: Codable {
  private enum CodingKeys: String, CodingKey {
    case score
    case band
    case penalties
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      score: container.decode(Int.self, forKey: .score),
      band: container.decode(ReadinessBand.self, forKey: .band),
      penalties: container.decode([ReadinessPenalty].self, forKey: .penalties)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(score, forKey: .score)
    try container.encode(band, forKey: .band)
    try container.encode(penalties, forKey: .penalties)
  }
}

extension DomainModels.ReadinessPenalty: Codable {
  private enum CodingKeys: String, CodingKey {
    case factor
    case points
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      factor: container.decode(PenaltyFactor.self, forKey: .factor),
      points: container.decode(Int.self, forKey: .points)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(factor, forKey: .factor)
    try container.encode(points, forKey: .points)
  }
}

extension DomainModels.SafetyGate: Codable {
  private enum CodingKeys: String, CodingKey {
    case triggered
    case reasons
    case overrideTo
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      triggered: container.decode(Bool.self, forKey: .triggered),
      reasons: container.decode([SafetyReason].self, forKey: .reasons),
      overrideTo: container.decodeIfPresent(Card.self, forKey: .overrideTo)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(triggered, forKey: .triggered)
    try container.encode(reasons, forKey: .reasons)
    try container.encodeIfPresent(overrideTo, forKey: .overrideTo)
  }
}

extension DomainModels.SessionBlock: Codable {
  private enum CodingKeys: String, CodingKey {
    case card
    case intensity
    case zoneTarget
    case durationMinLow
    case durationMinHigh
    case hrCapBpm
    case cadenceSpm
    case flags
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      card: container.decode(Card.self, forKey: .card),
      intensity: container.decode(Intensity.self, forKey: .intensity),
      zoneTarget: container.decodeIfPresent(Zone.self, forKey: .zoneTarget),
      durationMinLow: container.decode(Int.self, forKey: .durationMinLow),
      durationMinHigh: container.decode(Int.self, forKey: .durationMinHigh),
      hrCapBpm: container.decodeIfPresent(Int.self, forKey: .hrCapBpm),
      cadenceSpm: container.decodeIfPresent(Int.self, forKey: .cadenceSpm),
      flags: container.decode([Flag].self, forKey: .flags)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(card, forKey: .card)
    try container.encode(intensity, forKey: .intensity)
    try container.encodeIfPresent(zoneTarget, forKey: .zoneTarget)
    try container.encode(durationMinLow, forKey: .durationMinLow)
    try container.encode(durationMinHigh, forKey: .durationMinHigh)
    try container.encodeIfPresent(hrCapBpm, forKey: .hrCapBpm)
    try container.encodeIfPresent(cadenceSpm, forKey: .cadenceSpm)
    try container.encode(flags, forKey: .flags)
  }
}

extension DomainModels.PlannedSession: Codable {
  private enum CodingKeys: String, CodingKey {
    case card
    case tier
    case intensity
    case isHardDay
    case suggestedDay
    case zoneTarget
    case durationMinLow
    case durationMinHigh
    case flags
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      card: container.decode(Card.self, forKey: .card),
      tier: container.decode(Tier.self, forKey: .tier),
      intensity: container.decode(Intensity.self, forKey: .intensity),
      isHardDay: container.decode(Bool.self, forKey: .isHardDay),
      suggestedDay: container.decodeIfPresent(Weekday.self, forKey: .suggestedDay),
      zoneTarget: container.decodeIfPresent(Zone.self, forKey: .zoneTarget),
      durationMinLow: container.decodeIfPresent(Int.self, forKey: .durationMinLow),
      durationMinHigh: container.decodeIfPresent(Int.self, forKey: .durationMinHigh),
      flags: container.decode([Flag].self, forKey: .flags)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(card, forKey: .card)
    try container.encode(tier, forKey: .tier)
    try container.encode(intensity, forKey: .intensity)
    try container.encode(isHardDay, forKey: .isHardDay)
    try container.encodeIfPresent(suggestedDay, forKey: .suggestedDay)
    try container.encodeIfPresent(zoneTarget, forKey: .zoneTarget)
    try container.encodeIfPresent(durationMinLow, forKey: .durationMinLow)
    try container.encodeIfPresent(durationMinHigh, forKey: .durationMinHigh)
    try container.encode(flags, forKey: .flags)
  }
}

extension DomainModels.MacroFocus: Codable {
  private enum CodingKeys: String, CodingKey {
    case dayType
    case caloriesKcal
    case proteinG
    case carbsG
    case fatGLow
    case fatGHigh
    case hydrationLLow
    case hydrationLHigh
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      dayType: container.decode(DayType.self, forKey: .dayType),
      caloriesKcal: container.decode(Int.self, forKey: .caloriesKcal),
      proteinG: container.decode(Int.self, forKey: .proteinG),
      carbsG: container.decode(Int.self, forKey: .carbsG),
      fatGLow: container.decode(Int.self, forKey: .fatGLow),
      fatGHigh: container.decode(Int.self, forKey: .fatGHigh),
      hydrationLLow: container.decode(Double.self, forKey: .hydrationLLow),
      hydrationLHigh: container.decode(Double.self, forKey: .hydrationLHigh)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(dayType, forKey: .dayType)
    try container.encode(caloriesKcal, forKey: .caloriesKcal)
    try container.encode(proteinG, forKey: .proteinG)
    try container.encode(carbsG, forKey: .carbsG)
    try container.encode(fatGLow, forKey: .fatGLow)
    try container.encode(fatGHigh, forKey: .fatGHigh)
    try container.encode(hydrationLLow, forKey: .hydrationLLow)
    try container.encode(hydrationLHigh, forKey: .hydrationLHigh)
  }
}

extension DomainModels.NarrativeSection: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case heading
    case body
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      type: container.decode(NarrativeType.self, forKey: .type),
      heading: container.decode(String.self, forKey: .heading),
      body: container.decode(String.self, forKey: .body)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(heading, forKey: .heading)
    try container.encode(body, forKey: .body)
  }
}

extension DomainModels.IntakeSummary: Codable {
  private enum CodingKeys: String, CodingKey {
    case date
    case caloriesKcal
    case proteinG
    case carbsG
    case fatG
    case fiberG
    case waterL
    case vsTarget
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      date: container.decode(Date.self, forKey: .date),
      caloriesKcal: container.decodeIfPresent(Int.self, forKey: .caloriesKcal),
      proteinG: container.decodeIfPresent(Int.self, forKey: .proteinG),
      carbsG: container.decodeIfPresent(Int.self, forKey: .carbsG),
      fatG: container.decodeIfPresent(Int.self, forKey: .fatG),
      fiberG: container.decodeIfPresent(Int.self, forKey: .fiberG),
      waterL: container.decodeIfPresent(Double.self, forKey: .waterL),
      vsTarget: container.decode(IntakeVsTarget.self, forKey: .vsTarget)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(date, forKey: .date)
    try container.encodeIfPresent(caloriesKcal, forKey: .caloriesKcal)
    try container.encodeIfPresent(proteinG, forKey: .proteinG)
    try container.encodeIfPresent(carbsG, forKey: .carbsG)
    try container.encodeIfPresent(fatG, forKey: .fatG)
    try container.encodeIfPresent(fiberG, forKey: .fiberG)
    try container.encodeIfPresent(waterL, forKey: .waterL)
    try container.encode(vsTarget, forKey: .vsTarget)
  }
}

extension DomainModels.IntakeVsTarget: Codable {
  private enum CodingKeys: String, CodingKey {
    case caloriesPct
    case proteinHit
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      caloriesPct: container.decode(Double.self, forKey: .caloriesPct),
      proteinHit: container.decode(Bool.self, forKey: .proteinHit)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(caloriesPct, forKey: .caloriesPct)
    try container.encode(proteinHit, forKey: .proteinHit)
  }
}

extension DomainModels.WeeklyBudgets: Codable {
  private enum CodingKeys: String, CodingKey {
    case hardDays
    case strengthSessions
    case longRunKm
    case deload
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      hardDays: container.decode(Int.self, forKey: .hardDays),
      strengthSessions: container.decode(Int.self, forKey: .strengthSessions),
      longRunKm: container.decodeIfPresent(Double.self, forKey: .longRunKm),
      deload: container.decode(Bool.self, forKey: .deload)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hardDays, forKey: .hardDays)
    try container.encode(strengthSessions, forKey: .strengthSessions)
    try container.encodeIfPresent(longRunKm, forKey: .longRunKm)
    try container.encode(deload, forKey: .deload)
  }
}

extension DomainModels.WeeklyTargets: Codable {
  private enum CodingKeys: String, CodingKey {
    case totalRunKm
    case easyRunRatio
    case strengthSessions
    case hardDays
    case cadenceSpm
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      totalRunKm: container.decodeIfPresent(Double.self, forKey: .totalRunKm),
      easyRunRatio: container.decode(Double.self, forKey: .easyRunRatio),
      strengthSessions: container.decode(Int.self, forKey: .strengthSessions),
      hardDays: container.decode(Int.self, forKey: .hardDays),
      cadenceSpm: container.decode(Int.self, forKey: .cadenceSpm)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(totalRunKm, forKey: .totalRunKm)
    try container.encode(easyRunRatio, forKey: .easyRunRatio)
    try container.encode(strengthSessions, forKey: .strengthSessions)
    try container.encode(hardDays, forKey: .hardDays)
    try container.encode(cadenceSpm, forKey: .cadenceSpm)
  }
}

extension DomainModels.WeeklyNutrition: Codable {
  private enum CodingKeys: String, CodingKey {
    case proteinG
    case fatGLow
    case fatGHigh
    case hydrationLLow
    case hydrationLHigh
    case avgCaloriesKcal
    case dayTypePattern
    case restDay
    case lastWeek
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      proteinG: container.decode(Int.self, forKey: .proteinG),
      fatGLow: container.decode(Int.self, forKey: .fatGLow),
      fatGHigh: container.decode(Int.self, forKey: .fatGHigh),
      hydrationLLow: container.decode(Double.self, forKey: .hydrationLLow),
      hydrationLHigh: container.decode(Double.self, forKey: .hydrationLHigh),
      avgCaloriesKcal: container.decode(Int.self, forKey: .avgCaloriesKcal),
      dayTypePattern: container.decode([DayTypePatternEntry].self, forKey: .dayTypePattern),
      restDay: container.decodeIfPresent(RestDayNutrition.self, forKey: .restDay),
      lastWeek: container.decodeIfPresent(LastWeekNutrition.self, forKey: .lastWeek)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(proteinG, forKey: .proteinG)
    try container.encode(fatGLow, forKey: .fatGLow)
    try container.encode(fatGHigh, forKey: .fatGHigh)
    try container.encode(hydrationLLow, forKey: .hydrationLLow)
    try container.encode(hydrationLHigh, forKey: .hydrationLHigh)
    try container.encode(avgCaloriesKcal, forKey: .avgCaloriesKcal)
    try container.encode(dayTypePattern, forKey: .dayTypePattern)
    try container.encodeIfPresent(restDay, forKey: .restDay)
    try container.encodeIfPresent(lastWeek, forKey: .lastWeek)
  }
}

extension DomainModels.DayTypePatternEntry: Codable {
  private enum CodingKeys: String, CodingKey {
    case suggestedDay
    case dayType
    case caloriesKcal
    case carbsG
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      suggestedDay: container.decode(String.self, forKey: .suggestedDay),
      dayType: container.decode(DayType.self, forKey: .dayType),
      caloriesKcal: container.decode(Int.self, forKey: .caloriesKcal),
      carbsG: container.decode(Int.self, forKey: .carbsG)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(suggestedDay, forKey: .suggestedDay)
    try container.encode(dayType, forKey: .dayType)
    try container.encode(caloriesKcal, forKey: .caloriesKcal)
    try container.encode(carbsG, forKey: .carbsG)
  }
}

extension DomainModels.RestDayNutrition: Codable {
  private enum CodingKeys: String, CodingKey {
    case caloriesKcal
    case carbsG
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      caloriesKcal: container.decode(Int.self, forKey: .caloriesKcal),
      carbsG: container.decode(Int.self, forKey: .carbsG)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(caloriesKcal, forKey: .caloriesKcal)
    try container.encode(carbsG, forKey: .carbsG)
  }
}

extension DomainModels.LastWeekNutrition: Codable {
  private enum CodingKeys: String, CodingKey {
    case avgCaloriesKcal
    case avgProteinG
    case proteinHitDays
    case daysOverTarget
    case daysUnderTarget
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      avgCaloriesKcal: container.decodeIfPresent(Int.self, forKey: .avgCaloriesKcal),
      avgProteinG: container.decodeIfPresent(Int.self, forKey: .avgProteinG),
      proteinHitDays: container.decodeIfPresent(Int.self, forKey: .proteinHitDays),
      daysOverTarget: container.decodeIfPresent(Int.self, forKey: .daysOverTarget),
      daysUnderTarget: container.decodeIfPresent(Int.self, forKey: .daysUnderTarget)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(avgCaloriesKcal, forKey: .avgCaloriesKcal)
    try container.encodeIfPresent(avgProteinG, forKey: .avgProteinG)
    try container.encodeIfPresent(proteinHitDays, forKey: .proteinHitDays)
    try container.encodeIfPresent(daysOverTarget, forKey: .daysOverTarget)
    try container.encodeIfPresent(daysUnderTarget, forKey: .daysUnderTarget)
  }
}

extension DomainModels.Profile: Codable {
  private enum CodingKeys: String, CodingKey {
    case athlete
    case zones
    case thresholds
    case meta
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      athlete: container.decode(Athlete.self, forKey: .athlete),
      zones: container.decode(Zones.self, forKey: .zones),
      thresholds: container.decode(Thresholds.self, forKey: .thresholds),
      meta: container.decode(ProfileMeta.self, forKey: .meta)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(athlete, forKey: .athlete)
    try container.encode(zones, forKey: .zones)
    try container.encode(thresholds, forKey: .thresholds)
    try container.encode(meta, forKey: .meta)
  }
}

extension DomainModels.Athlete: Codable {
  private enum CodingKeys: String, CodingKey {
    case age
    case sex
    case heightCm
    case goalWeightKg
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      age: container.decode(Int.self, forKey: .age),
      sex: container.decode(String.self, forKey: .sex),
      heightCm: container.decode(Int.self, forKey: .heightCm),
      goalWeightKg: container.decode(Double.self, forKey: .goalWeightKg)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(age, forKey: .age)
    try container.encode(sex, forKey: .sex)
    try container.encode(heightCm, forKey: .heightCm)
    try container.encode(goalWeightKg, forKey: .goalWeightKg)
  }
}

// swiftlint:disable identifier_name

extension DomainModels.Zones: Codable {
  private enum CodingKeys: String, CodingKey {
    case z1
    case z2
    case z3
    case z4
    case z5
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      z1: container.decode(ZoneRange.self, forKey: .z1),
      z2: container.decode(ZoneRange.self, forKey: .z2),
      z3: container.decode(ZoneRange.self, forKey: .z3),
      z4: container.decode(ZoneRange.self, forKey: .z4),
      z5: container.decode(ZoneRange.self, forKey: .z5)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(z1, forKey: .z1)
    try container.encode(z2, forKey: .z2)
    try container.encode(z3, forKey: .z3)
    try container.encode(z4, forKey: .z4)
    try container.encode(z5, forKey: .z5)
  }
}

// swiftlint:enable identifier_name

extension DomainModels.ZoneRange: Codable {
  private enum CodingKeys: String, CodingKey {
    case low
    case high
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      low: container.decode(Int.self, forKey: .low),
      high: container.decode(Int.self, forKey: .high)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(low, forKey: .low)
    try container.encode(high, forKey: .high)
  }
}

extension DomainModels.Thresholds: Codable {
  private enum CodingKeys: String, CodingKey {
    case maxHr
    case rhrBaseline
    case hrvBaselineMs
    case easyHrCap
    case cadenceCurrentSpm
    case cadenceTargetSpm
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      maxHr: container.decode(Int.self, forKey: .maxHr),
      rhrBaseline: container.decode(Int.self, forKey: .rhrBaseline),
      hrvBaselineMs: container.decode(Int.self, forKey: .hrvBaselineMs),
      easyHrCap: container.decode(Int.self, forKey: .easyHrCap),
      cadenceCurrentSpm: container.decode(Int.self, forKey: .cadenceCurrentSpm),
      cadenceTargetSpm: container.decode(Int.self, forKey: .cadenceTargetSpm)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(maxHr, forKey: .maxHr)
    try container.encode(rhrBaseline, forKey: .rhrBaseline)
    try container.encode(hrvBaselineMs, forKey: .hrvBaselineMs)
    try container.encode(easyHrCap, forKey: .easyHrCap)
    try container.encode(cadenceCurrentSpm, forKey: .cadenceCurrentSpm)
    try container.encode(cadenceTargetSpm, forKey: .cadenceTargetSpm)
  }
}

extension DomainModels.ProfileMeta: Codable {
  private enum CodingKeys: String, CodingKey {
    case constitutionVersion
    case constantsRecomputedWeek
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      constitutionVersion: container.decode(String.self, forKey: .constitutionVersion),
      constantsRecomputedWeek: container.decodeIfPresent(String.self, forKey: .constantsRecomputedWeek)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(constitutionVersion, forKey: .constitutionVersion)
    try container.encodeIfPresent(constantsRecomputedWeek, forKey: .constantsRecomputedWeek)
  }
}
