import DomainModels
import SwiftUI

/// A small presentation value normalizing a daily `SessionBlock` and a weekly `PlannedSession` so one
/// `SessionCard` view renders both consistently (DECISIONS #1). Weekly sessions carry no HR cap /
/// cadence but add an `isHardDay` marker.
struct SessionCardModel {
  var card: Card
  var intensity: Intensity
  var zoneTarget: Zone?
  var durationMinLow: Int?
  var durationMinHigh: Int?
  var hrCapBpm: Int?
  var cadenceSpm: Int?
  var flags: [Flag]
  var isHardDay: Bool

  init(_ block: SessionBlock) {
    card = block.card
    intensity = block.intensity
    zoneTarget = block.zoneTarget
    durationMinLow = block.durationMinLow
    durationMinHigh = block.durationMinHigh
    hrCapBpm = block.hrCapBpm
    cadenceSpm = block.cadenceSpm
    flags = block.flags
    isHardDay = false
  }

  init(_ planned: PlannedSession) {
    card = planned.card
    intensity = planned.intensity
    zoneTarget = planned.zoneTarget
    durationMinLow = planned.durationMinLow
    durationMinHigh = planned.durationMinHigh
    // Weekly sessions carry no HR cap / cadence.
    hrCapBpm = nil
    cadenceSpm = nil
    flags = planned.flags
    isHardDay = planned.isHardDay
  }
}

/// The hero session component — renders a session's card name, duration range, an embedded `ZoneChip`,
/// the intensity accent, the optional HR cap / cadence cues, and the flags as quiet footnotes. Pure
/// (state in / view out); the feature passes the zone bpm range in (from `ProfileRepository.zones()`).
public struct SessionCard: View {
  let model: SessionCardModel
  let zoneRange: ZoneRange?

  public init(_ block: SessionBlock, zoneRange: ZoneRange? = nil) {
    model = SessionCardModel(block)
    self.zoneRange = zoneRange
  }

  public init(_ planned: PlannedSession, zoneRange: ZoneRange? = nil) {
    model = SessionCardModel(planned)
    self.zoneRange = zoneRange
  }

  var durationText: String? {
    guard let low = model.durationMinLow, let high = model.durationMinHigh else { return nil }
    return low == high ? "\(low) min" : "\(low)–\(high) min"
  }

  /// `effort_based` (long run) — de-emphasize the HR ceiling; lean on duration + cadence ("by feel").
  var isEffortBased: Bool { model.flags.contains(.effortBased) }
  /// `append_to_easy` (strides) — render an add-on attached to the run, not a standalone card.
  var hasStridesAddon: Bool { model.flags.contains(.appendToEasy) }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space12) {
      header
      if let zone = model.zoneTarget, let zoneRange {
        ZoneChip(zone: zone, range: zoneRange)
      }
      detailRow
      if model.isHardDay {
        Pill("Hard day", tone: .warning, leading: .dot)
      }
      if hasStridesAddon {
        stridesAddon
      }
      if !model.flags.isEmpty {
        flagRow
      }
    }
    .padding(CoachSpacing.space16)
    .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(CoachColor.surface))
    .overlay(RoundedRectangle(cornerRadius: CoachRadius.card).stroke(CoachColor.border, lineWidth: 1))
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2) {
        Text(model.card.label).font(CoachFont.cardHeadline).foregroundStyle(CoachColor.foreground)
        if let durationText {
          Text(durationText).font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foregroundMuted)
        }
      }
      Spacer(minLength: 0)
      Pill(model.intensity.label, tone: intensityTone, leading: .icon(model.intensity.iconName))
    }
  }

  private var intensityTone: Tone {
    switch model.intensity {
    case .easy: .accent
    case .quality: .negative
    case .recovery: .positive
    }
  }

  @ViewBuilder private var detailRow: some View {
    let cues = detailCues
    if !cues.isEmpty {
      HStack(spacing: CoachSpacing.space8) {
        ForEach(cues, id: \.self) { cue in
          Chip(cue)
        }
      }
    }
  }

  /// Numeric cues authored over the session's `data` (not enum keys). For an `effort_based` run the HR
  /// cap is suppressed in favor of a "By feel" cue + cadence (the cap stays in the model, just quieted).
  var detailCues: [String] {
    var cues: [String] = []
    if isEffortBased {
      cues.append("By feel")
    } else if let cap = model.hrCapBpm {
      cues.append("HR ≤\(cap) bpm")
    }
    if let cadence = model.cadenceSpm {
      cues.append("~\(cadence) spm")
    }
    return cues
  }

  private var stridesAddon: some View {
    HStack(spacing: CoachSpacing.space6) {
      Image(systemName: Icon.prehab.systemName).foregroundStyle(CoachColor.accent)
      Text("Strides — attached to this run")
        .font(CoachFont.caption)
        .foregroundStyle(CoachColor.foregroundMuted)
    }
    .padding(.horizontal, CoachSpacing.space10)
    .padding(.vertical, CoachSpacing.space6)
    .background(RoundedRectangle(cornerRadius: CoachRadius.sm).fill(CoachColor.accentSoft))
  }

  private var flagRow: some View {
    HStack(spacing: CoachSpacing.space6) {
      ForEach(Array(model.flags.enumerated()), id: \.offset) { _, flag in
        FlagBadge(flag: flag)
      }
    }
  }
}
