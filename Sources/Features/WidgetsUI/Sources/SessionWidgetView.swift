import DesignSystem
import DomainModels
import SwiftUI

/// The today's-session widget view (Phase 21.2) — pure SwiftUI over a derived `SessionWidgetState`,
/// one branch per `Layout` so the snapshot target renders every family without WidgetKit. The
/// WidgetKit wrapper (`SessionWidget.swift`) maps `widgetFamily` → `Layout` and applies
/// `widgetURL`/`containerBackground`. Home-screen layouts own their padding (the widget disables
/// system content margins); accessory layouts are margin-free system text.
public struct SessionWidgetView: View {
  /// The rendered family: home-screen small/medium + lock-screen inline/rectangular.
  public enum Layout: Sendable {
    case small, medium, inline, rectangular
  }

  let state: SessionWidgetState
  let layout: Layout

  public init(state: SessionWidgetState, layout: Layout) {
    self.state = state
    self.layout = layout
  }

  public var body: some View {
    switch layout {
    case .small:
      SmallSessionLayout(state: state)
    case .medium:
      MediumSessionLayout(state: state)
    case .inline:
      Text(state.summaryLine)
    case .rectangular:
      RectangularSessionLayout(state: state)
    }
  }
}

/// systemSmall — eyebrow, card name + intensity, then the duration numeral and the zone/HR badges.
private struct SmallSessionLayout: View {
  let state: SessionWidgetState

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      WidgetEyebrow("TODAY'S SESSION")
      switch state {
      case let .session(block):
        Text(block.card.label)
          .font(.coachTextMd)
          .foregroundStyle(.coachForeground)
          .lineLimit(2)
        Text(block.intensity.label)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
        Spacer(minLength: 0)
        DurationLine(block: block, size: .small)
        SessionBadges(block: block)
      case .rest:
        RestStateBody(headline: "Rest day", detail: "Let the work land", icon: "bed.double.fill")
      case let .gate(reasons):
        RestStateBody(headline: "Rest today", detail: gateDetail(reasons), icon: "heart.fill")
      case .stale:
        StaleBody()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
  }
}

/// systemMedium — the small content spread into a name/intensity column with the duration + badges
/// on the trailing edge; the rest/gate/stale states gain room for their full detail line.
private struct MediumSessionLayout: View {
  let state: SessionWidgetState

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      WidgetEyebrow("TODAY'S SESSION")
      switch state {
      case let .session(block):
        HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
          VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
            Text(block.card.label)
              .font(.coachTextXl)
              .foregroundStyle(.coachForeground)
              .lineLimit(2)
            Text(block.intensity.label)
              .font(.coachTextSm)
              .foregroundStyle(.coachForegroundMuted)
          }
          Spacer(minLength: CoachSpacing.spaceSm)
          DurationLine(block: block, size: .medium)
        }
        Spacer(minLength: 0)
        SessionBadges(block: block)
      case .rest:
        RestStateBody(headline: "Rest day", detail: "Let the work land", icon: "bed.double.fill")
      case let .gate(reasons):
        RestStateBody(headline: "Rest today", detail: gateDetail(reasons), icon: "heart.fill")
      case .stale:
        StaleBody()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
  }
}

/// accessoryRectangular — a caption over the shared one-line summary (system-rendered colors).
private struct RectangularSessionLayout: View {
  let state: SessionWidgetState

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text("TODAY")
        .font(.coachText2xs)
        .tracking(1)
      Text(state.summaryLine)
        .font(.coachTextSm)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The big duration figure + "min", baseline-aligned; the medium family renders it larger.
private struct DurationLine: View {
  enum Size {
    case small, medium
  }

  let block: SessionBlock
  let size: Size

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: CoachSpacing.spaceXs) {
      Text(block.durationText)
        .font(size == .small ? .coachTextXl : .coachText2xl)
        .foregroundStyle(.coachForeground)
      Text("min")
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}

/// The zone-target chip (zone-colored dot) + the model's HR-cap line — each half only when present;
/// nothing renders when the block carries neither.
private struct SessionBadges: View {
  let block: SessionBlock

  var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      if let zone = block.zoneTarget {
        Chip(zone.badgeLabel, leading: .dot(zone.badgeColor), textColor: .coachForeground)
      }
      if let cap = block.hrCapBpm {
        Text("≤ \(cap) bpm")
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
  }
}

/// The dedicated rest-family body — icon, headline, detail. Shared by the rest card and the tripped
/// gate (distinct copy/icon per state); soft accent, never an alarm tone (PRD §9.2).
private struct RestStateBody: View {
  let headline: String
  let detail: String
  let icon: String

  var body: some View {
    Image(systemName: icon)
      .font(.coachTextLg)
      .foregroundStyle(.coachAccent)
      .padding(.top, CoachSpacing.space2xs)
    Text(headline)
      .font(.coachTextMd)
      .foregroundStyle(.coachForeground)
    Text(detail)
      .font(.coachTextXs)
      .foregroundStyle(.coachForegroundMuted)
      .lineLimit(3)
  }
}

/// The stale placeholder — mirrors the skeleton's "no current brief" treatment.
private struct StaleBody: View {
  var body: some View {
    Text("—")
      .font(.coachText3xl)
      .foregroundStyle(.coachForegroundSubtle)
    Text("No brief yet")
      .font(.coachTextSm)
      .foregroundStyle(.coachForegroundMuted)
  }
}

/// The gate detail line — the typed reason labels joined, with a graceful fallback for an empty list
/// (never a blank line).
private func gateDetail(_ reasons: [SafetyReason]) -> String {
  reasons.isEmpty ? "Recovery comes first" : reasons.map(\.label).joined(separator: " · ")
}

private extension Zone {
  /// The zone's domain color token (SemanticColors Z1–Z5 ramp) for the badge dot.
  var badgeColor: Color {
    switch self {
    case .z1: .coachZ1
    case .z2: .coachZ2
    case .z3: .coachZ3
    case .z4: .coachZ4
    case .z5: .coachZ5
    }
  }
}
