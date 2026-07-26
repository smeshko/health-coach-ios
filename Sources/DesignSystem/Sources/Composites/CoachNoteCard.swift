import DomainModels
import SwiftUI

/// The coach's narrative as its **own card** — the day's session prose lifted out of the `SessionCard`s
/// (where a brief-level slice repeated identically on every carousel candidate) into a single surface
/// below the carousel: a "COACH'S NOTE" icon-plus-eyebrow header above the verbatim
/// `NarrativeRenderer` body.
///
/// **Pure and verbatim** (ARCHITECTURE principle #1): the parent hands in the already-filtered slice
/// (the `.session` sections, plus `.caution` on a forced-rest day) and this card authors no prose — only
/// the header chrome (the quote icon, the eyebrow case + tracking) is DS-owned. The chrome matches the
/// Today card family (`ReadinessComponentView` / the fuel panel): `spaceMd` padding on `.coachSurface`
/// inside the `CoachRadius.card` continuous round-rect with the 1pt `.coachBorder` stroke.
///
/// An empty slice is the caller's concern — consumers wrap the card in `if !narrative.isEmpty` (the
/// in-card slot's old rule), so a brief without session prose renders no empty shell.
public struct CoachNoteCard: View {
  let sections: [NarrativeSection]

  public init(_ sections: [NarrativeSection]) {
    self.sections = sections
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      HStack(spacing: CoachSpacing.spaceXs) {
        Image(systemName: "quote.opening")
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
        Text("Coach's note")
          .font(.coachText2xs)
          .textCase(.uppercase)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundMuted)
      }
      NarrativeRenderer(sections)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
        .fill(.coachSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .strokeBorder(.coachBorder, lineWidth: 1)
        )
    )
  }
}

/// Named constants — the eyebrow's letter tracking (the `NarrativeRenderer`/`SessionCard` value).
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.8
}
