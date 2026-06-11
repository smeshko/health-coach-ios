import DomainModels
import SwiftUI

/// Renders an ordered `[NarrativeSection]` **verbatim** (ARCHITECTURE principle #1): per section a subtle
/// uppercase eyebrow — the model `heading`, the design's "COACH NOTE" / "WHY THIS TODAY?" treatment —
/// above the `body` paragraph, in the order given. The `type == .caution` section renders instead as the
/// soft "gentle note" callout (a leading shield icon + heading + body on a soft-accent surface — calm,
/// never an alarm token).
///
/// The component **authors no prose**: only the section chrome is DS-owned (the eyebrow case + tracking,
/// the callout surface + icon); `section.heading` and `section.body` are passed through untouched. The
/// parent hands in the already-filtered slice (e.g. just the `.session` sections for the in-card slot, or
/// the `.nutrition` + `.caution` pair under the fuel card); this view renders whatever it is given.
public struct NarrativeRenderer: View {
  let sections: [NarrativeSection]

  public init(_ sections: [NarrativeSection]) {
    self.sections = sections
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
        if section.type == .caution {
          CautionCallout(heading: section.heading, message: section.body)
        } else {
          EyebrowSection(heading: section.heading, message: section.body)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A standard narrative slice — the `heading` as a subtle uppercase eyebrow above the `body` paragraph.
/// Both strings are rendered verbatim; only the eyebrow's case/tracking is presentation.
private struct EyebrowSection: View {
  let heading: String
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      // An empty heading (e.g. the in-card session narrative) renders as a plain paragraph — no eyebrow.
      if !heading.isEmpty {
        Text(heading)
          .font(.coachText2xs)
          .textCase(.uppercase)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundSubtle)
      }
      Text(message)
        .font(.coachTextMd)
        .foregroundStyle(.coachForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The `.caution` section as the soft "gentle note" callout — a leading shield icon + heading + body on a
/// soft-accent surface (the `Banner` anatomy, in `Tone.accent`'s soft fill). Deliberately calm: the
/// heading carries the accent, the body stays muted foreground, and the fill is the soft tint — never a
/// warning/negative alarm tone.
private struct CautionCallout: View {
  let heading: String
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      Image(systemName: "checkmark.shield")
        .font(.system(size: Metrics.calloutIcon))
        .foregroundStyle(.coachAccent)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(heading)
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
        Text(message)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(Tone.accent.fill))
  }
}

/// Named constants — the eyebrow's letter tracking and the callout icon's point size.
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.8
  static let calloutIcon: CGFloat = 18
}
