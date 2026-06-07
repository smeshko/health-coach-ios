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

  init(model: SessionCardModel, zoneRange: ZoneRange?) {
    self.model = model
    self.zoneRange = zoneRange
  }

  var durationText: String? {
    guard let low = model.durationMinLow, let high = model.durationMinHigh else { return nil }
    return low == high ? "\(low) min" : "\(low)–\(high) min"
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space12) {
      header
      if let zone = model.zoneTarget, let zoneRange {
        ZoneChip(zone: zone, range: zoneRange)
      }
      detailRow
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

  /// Numeric cues authored over the session's `data` (not enum keys): HR cap + cadence when present.
  var detailCues: [String] {
    var cues: [String] = []
    if let cap = model.hrCapBpm {
      cues.append("HR ≤\(cap) bpm")
    }
    if let cadence = model.cadenceSpm {
      cues.append("~\(cadence) spm")
    }
    return cues
  }

  private var flagRow: some View {
    HStack(spacing: CoachSpacing.space6) {
      ForEach(Array(model.flags.enumerated()), id: \.offset) { _, flag in
        FlagBadge(flag: flag)
      }
    }
  }
}
