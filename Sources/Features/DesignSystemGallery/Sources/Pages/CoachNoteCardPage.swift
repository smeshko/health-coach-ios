import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `CoachNoteCard`: the day's session prose as its own card below the
/// session carousel (the "COACH'S NOTE" icon-plus-eyebrow header above the verbatim narrative). Two
/// states: the plain `.session` paragraph (empty heading → no inner eyebrow), and the forced-rest
/// session + `.caution` pair (the caution renders as the soft gentle-note callout inside the card).
struct CoachNoteCardPage: View {
  var body: some View {
    GalleryScaffold(title: "CoachNoteCard") {
      stateLabel("Session narrative (plain paragraph)")
      CoachNoteCardSessionSection()
      stateLabel("Session + caution (forced-rest slice)")
      CoachNoteCardCautionSection()
    }
  }
}

/// The everyday state — the single `.session` paragraph the brief carries (empty heading, so the card's
/// own header is the only eyebrow).
struct CoachNoteCardSessionSection: View {
  var body: some View {
    coachNoteSectionColumn {
      CoachNoteCard([
        NarrativeSection(
          type: .session,
          heading: "",
          body: "Keep it conversational — you should be able to talk in full sentences the whole way. "
            + "Walk the hills, and finish with a few relaxed strides."
        ),
      ])
    }
  }
}

/// The forced-rest slice — the `.session` paragraph plus a `.caution` section, which the inner
/// `NarrativeRenderer` renders as the soft gentle-note callout.
struct CoachNoteCardCautionSection: View {
  var body: some View {
    coachNoteSectionColumn {
      CoachNoteCard([
        NarrativeSection(
          type: .session,
          heading: "",
          body: "Your body did the work — today it adapts. Nothing to prove."
        ),
        NarrativeSection(
          type: .caution,
          heading: "A gentle note",
          body: "Your resting heart rate is still elevated — keep today genuinely easy."
        ),
      ])
    }
  }
}

/// Shared column scaffold — the card on the app background with standard padding, device-fitting so
/// each section can be snapshotted whole (the `SessionCardPage` pattern).
@ViewBuilder
private func coachNoteSectionColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceMd)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
