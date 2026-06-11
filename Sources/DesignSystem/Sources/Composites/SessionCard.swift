import DomainModels
import SwiftUI

/// The daily session card (the 2026-06-10 anatomy) — **pure**: state in, view out. It renders only the
/// **displayed** session plus footer **label** slots; the inline SWAP-TO list, the expand/select state,
/// and the real swap/skip actions are the consuming feature's (8.4 `SessionFeature`, Decision 2). The
/// feature injects `onSwap`/`onSkip` (default no-op / hidden) and draws the list around the card.
///
/// The session's `card` selects the layout:
/// - **rest** (`card == .rest`) — the narrative, an authored optional-activity suggestion box, the "To
///   help recovery along" recovery row, and the "Rest is training too." footer; no numeral/zone/swap.
/// - **cardio** (a `zoneTarget`) — the duration numeral + the markerless `SegmentedBar.zones` bar.
/// - **strength / no-zone** — the duration numeral + the `SegmentedBar.range` 1–10 effort scale with the
///   **derived** zone→RPE band (`effortBand(for:)`).
///
/// Everything shown is model-backed or derived from the `SessionBlock`'s real fields (the category badge,
/// the header icon, the duration, the zone/effort meter, the flags row, the prehab add-on). The only
/// authored strings are short category chrome (the header sub-line, the rest-day suggestion + recovery
/// copy, the effort-scale endpoints); no fabricated RPE / reserve / rest / lift / cue copy (Decision 3).
public struct SessionCard: View {
  let block: SessionBlock
  let zoneRange: ZoneRange?
  let narrative: [NarrativeSection]
  let onSwap: (() -> Void)?
  let onSkip: (() -> Void)?

  public init(
    _ block: SessionBlock,
    zoneRange: ZoneRange? = nil,
    narrative: [NarrativeSection] = [],
    onSwap: (() -> Void)? = nil,
    onSkip: (() -> Void)? = nil
  ) {
    self.block = block
    self.zoneRange = zoneRange
    self.narrative = narrative
    self.onSwap = onSwap
    self.onSkip = onSkip
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      SessionHeader(block: block)
      if block.card == .rest {
        RestDayBody(narrative: narrative)
      } else {
        ActiveSessionBody(
          block: block, zoneRange: zoneRange, narrative: narrative, onSwap: onSwap, onSkip: onSkip
        )
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
        .fill(.coachSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .stroke(.coachBorder, lineWidth: 1)
        )
    )
  }
}

/// The card header — the derived card icon, the title (`Card.label`) + the authored category sub-line, and
/// the derived category badge.
private struct SessionHeader: View {
  let block: SessionBlock

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      IconBadge(headerIcon, shape: .square, size: .md, tone: .accent)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(block.card.label)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
          .fixedSize(horizontal: false, vertical: true) // wrap a long card name rather than truncate
        if let subtitle = headerSubtitle {
          Text(subtitle)
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
      }
      Spacer(minLength: CoachSpacing.spaceSm)
      Pill(categoryLabel, tone: .accent, uppercase: true)
    }
  }

  /// A family-level SF Symbol for the card (run / dumbbell / bed / …) — presentation derivation.
  private var headerIcon: String {
    switch block.card {
    case .rest: "bed.double.fill"
    case .strengthPush, .strengthPull, .strengthLower, .strengthFull: "dumbbell.fill"
    case .boxing, .boxingTechnique: "figure.boxing"
    case .mobility, .footPrehab, .glutePrehab, .activeRecovery: "figure.flexibility"
    default: "figure.run"
    }
  }

  /// The category badge — strength family → "Strength", rest → "Rest", else the intensity label
  /// (uppercased by the `Pill`).
  private var categoryLabel: String {
    switch block.card {
    case .strengthPush, .strengthPull, .strengthLower, .strengthFull: "Strength"
    case .rest: "Rest"
    default: block.intensity.label
    }
  }

  /// A short authored category descriptor under the title (DS chrome, not model data; nil → no sub-line).
  private var headerSubtitle: String? {
    switch block.card {
    case .easyRun, .longRun, .steadyCardio, .jumpRope: "Aerobic base"
    case .activeRecovery: "Easy movement"
    case .progressionRun, .threshold: "Tempo work"
    case .vo2, .hiit: "Hard intervals"
    case .strides: "Form & speed"
    case .strengthPush, .strengthPull, .strengthLower, .strengthFull: "Controlled load"
    case .boxing, .boxingTechnique: "Skill & conditioning"
    case .footPrehab, .glutePrehab, .mobility: "Prehab & mobility"
    case .rest: "Let the work land"
    }
  }
}

/// The active (non-rest) session body — duration numeral, the zone bar **or** the effort scale, the
/// model's bpm/spm line, the in-card narrative, the flags row + prehab add-on, and the footer slots.
private struct ActiveSessionBody: View {
  let block: SessionBlock
  let zoneRange: ZoneRange?
  let narrative: [NarrativeSection]
  let onSwap: (() -> Void)?
  let onSkip: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // Duration numeral + unit (the unit carries the intensity word for a cardio session).
      HStack(alignment: .lastTextBaseline, spacing: CoachSpacing.spaceXs) {
        Text(durationNumeral)
          .font(.coachText3xl)
          .foregroundStyle(.coachForeground)
        Text(durationUnit)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }

      if let zone = block.zoneTarget {
        // Cardio: the markerless Z1–Z5 bar, captioned by the passed `zoneRange` (omitted when nil),
        // with the model's bpm/spm line beneath.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          if let zoneRange {
            HStack {
              Text("Zone \(zone.number) target")
                .textCase(.uppercase)
                .tracking(Metrics.eyebrowTracking)
              Spacer(minLength: CoachSpacing.spaceSm)
              Text("\(zoneRange.low)–\(zoneRange.high) bpm")
            }
            .font(.coachText2xs)
            .foregroundStyle(.coachForegroundSubtle)
          }
          SegmentedBar.zones(target: zone.number)
          if let bpmSpm = bpmSpmLine {
            Text(bpmSpm)
              .font(.coachTextXs)
              .foregroundStyle(.coachForegroundMuted)
          }
        }
      } else {
        // Strength / no-zone: the 1–10 effort scale with the derived band, endpoints labelled (no "RPE N").
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          SegmentedBar.range(effortBand(for: block), total: Metrics.effortScale, tone: .warning)
          HStack {
            Text("1 · easy")
            Spacer(minLength: CoachSpacing.spaceSm)
            Text("max · \(Metrics.effortScale)")
          }
          .font(.coachText2xs)
          .foregroundStyle(.coachForegroundSubtle)
        }
      }

      if !narrative.isEmpty {
        NarrativeRenderer(narrative)
      }

      if !metaFlags.isEmpty {
        Divider().overlay(.coachBorder)
        Text(metaFlags.map(\.label).joined(separator: " · "))
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
      }
      if !prehabFlags.isEmpty {
        PrehabAddOn(labels: prehabFlags.map(\.label))
      }

      SessionFooter(onSwap: onSwap, onSkip: onSkip)
    }
  }

  /// The big duration figure — a low–high window, collapsing to a single value when the bounds match.
  private var durationNumeral: String {
    block.durationMinLow == block.durationMinHigh
      ? "\(block.durationMinLow)"
      : "\(block.durationMinLow)–\(block.durationMinHigh)"
  }

  /// The unit beside the numeral. A cardio session carries the intensity word ("minutes, easy"); other
  /// sessions stay "minutes" (no fabricated "· 4 lifts").
  private var durationUnit: String {
    block.zoneTarget != nil ? "minutes, \(block.intensity.label.lowercased())" : "minutes"
  }

  /// The bpm/spm line from the model — each half omitted when its field is nil, the whole line nil when
  /// neither is present.
  private var bpmSpmLine: String? {
    var parts: [String] = []
    if let bpm = block.hrCapBpm { parts.append("≤ \(bpm) bpm") }
    if let spm = block.cadenceSpm { parts.append("~\(spm) spm") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private var metaFlags: [Flag] { block.flags.filter { !$0.isPrehab } }
  private var prehabFlags: [Flag] { block.flags.filter(\.isPrehab) }
}

/// The rest-day body — the narrative, an authored optional-activity suggestion box, the "To help recovery
/// along" recovery row, and the "Rest is training too." footer. No duration / zone / flags / swap.
private struct RestDayBody: View {
  let narrative: [NarrativeSection]

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      if !narrative.isEmpty {
        NarrativeRenderer(narrative)
      }

      // Authored optional-activity suggestion (DS chrome — the model carries no such prompt).
      HStack(spacing: CoachSpacing.spaceSm) {
        IconBadge("figure.walk", shape: .square, size: .md, tone: .accent)
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          Text("Stretch your legs, if you feel like it")
            .font(.coachTextSm)
            .foregroundStyle(.coachForeground)
          Text("An easy 20 min walk — completely optional")
            .font(.coachTextXs)
            .foregroundStyle(.coachForegroundMuted)
        }
        Spacer(minLength: 0)
      }
      .padding(CoachSpacing.spaceMd)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous).fill(.coachSurfaceSunken)
      )

      VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
        Text("To help recovery along")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
        HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
          RecoveryItem(icon: "moon.fill", label: "Sleep well")
          RecoveryItem(icon: Icon.drop.systemName, label: "Hydrate")
          RecoveryItem(icon: "figure.mind.and.body", label: "Gentle mobility")
        }
      }

      HStack {
        Spacer()
        Label("Rest is training too.", systemImage: "heart")
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
        Spacer()
      }
    }
  }
}

/// One recovery suggestion — a soft circular icon badge above a muted label, sharing the row's width.
private struct RecoveryItem: View {
  let icon: String
  let label: String

  var body: some View {
    VStack(spacing: CoachSpacing.spaceXs) {
      IconBadge(icon, shape: .circle, size: .md, tone: .accent)
      Text(label)
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundMuted)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}

/// The prehab add-on — a soft sunken box with a leading "+" badge and the prehab flag label(s). Presence
/// and label are derived from the session's prehab-family flags; no fabricated duration/subtitle.
private struct PrehabAddOn: View {
  let labels: [String]

  var body: some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      Image(systemName: Icon.prehab.systemName)
        .font(.system(size: Metrics.prehabIcon))
        .foregroundStyle(.coachAccent)
      Text(labels.joined(separator: " · "))
        .font(.coachTextSm)
        .foregroundStyle(.coachForeground)
      Spacer(minLength: 0)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous).fill(.coachSurfaceSunken)
    )
  }
}

/// The footer affordance slots — "Skipping is fine today" (when `onSkip` is set) and "Swap" (when
/// `onSwap` is set). The card only renders the labels + forwards taps; the actions are the feature's.
private struct SessionFooter: View {
  let onSwap: (() -> Void)?
  let onSkip: (() -> Void)?

  var body: some View {
    if onSwap != nil || onSkip != nil {
      HStack {
        if let onSkip {
          Button(action: onSkip) {
            Label("Skipping is fine today", systemImage: "heart")
              .font(.coachTextSm)
          }
        }
        Spacer(minLength: CoachSpacing.spaceSm)
        if let onSwap {
          Button(action: onSwap) {
            HStack(spacing: CoachSpacing.space2xs) {
              Text("Swap")
              Image(systemName: "chevron.right")
            }
            .font(.coachTextSm)
          }
        }
      }
      .buttonStyle(.plain)
      .foregroundStyle(.coachAccent)
    }
  }
}

private extension Flag {
  /// Prehab-family flags become the add-on chip rather than a meta-row entry.
  var isPrehab: Bool {
    switch self {
    case .prehabFoot, .prehabGlute: true
    default: false
    }
  }
}

private extension Zone {
  /// The 1…5 ordinal the `SegmentedBar.zones(target:)` API takes.
  var number: Int {
    switch self {
    case .z1: 1
    case .z2: 2
    case .z3: 3
    case .z4: 4
    case .z5: 5
    }
  }
}

/// Eyebrow tracking, icon sizes, and the effort scale length — named constants, no inline literals.
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.8
  static let prehabIcon: CGFloat = 22
  static let effortScale = 10
}
