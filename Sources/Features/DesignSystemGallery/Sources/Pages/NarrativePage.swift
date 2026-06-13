import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `NarrativeRenderer` (verbatim narrative sections). Shows the in-card
/// eyebrow sections (summary + "why this today?" + COACH NOTE) on a surface card, then the standalone
/// `.caution` "gentle note" callout on the background, mirroring `Today · Nutrition.png`.
///
/// The matrix fits one device frame, so the page wraps a single device-fitting section
/// (`NarrativeGallerySection`) that the snapshot tests render directly (not the scrolling page).
struct NarrativePage: View {
  var body: some View {
    GalleryScaffold(title: "Narrative") {
      NarrativeGallerySection()
    }
  }
}

/// The device-fitting `NarrativeRenderer` matrix. Named `NarrativeGallerySection` (not
/// `NarrativeSection`) to avoid colliding with `DomainModels.NarrativeSection` — the model type the
/// renderer consumes in this same file.
struct NarrativeGallerySection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      stateLabel("Eyebrow sections (summary + session)")
      narrativeSectionCard {
        NarrativeRenderer([
          NarrativeSection(
            type: .summary,
            heading: "Good morning",
            body: "You're recovered and clear to train. Short sleep and yesterday's boxing took "
              + "the edge off, so today is a relaxed aerobic run — nothing that digs a hole. Keep it "
              + "genuinely easy."
          ),
          NarrativeSection(
            type: .session,
            heading: "Why this today?",
            body: "Keep it honestly easy — this pace will feel humblingly slow at first, and that "
              + "is exactly the point. Walk the hills if you need to, breathe through your nose, and "
              + "finish with 4–6 relaxed strides on flat ground."
          ),
        ])
      }

      stateLabel("Coach note")
      narrativeSectionCard {
        NarrativeRenderer([
          NarrativeSection(
            type: .nutrition,
            heading: "Coach note",
            body: "Protein is the non-negotiable — hit 165 g from lactose-safe sources (Greek "
              + "yogurt, kefir, whey isolate). Keep fat moderate and split across meals to go easy on "
              + "your gallbladder, and keep lemon water going through the day."
          ),
        ])
      }

      stateLabel("Gentle note (caution callout)")
      NarrativeRenderer([
        NarrativeSection(
          type: .caution,
          heading: "A gentle note",
          body: "You flagged mild gut sensitivity earlier this week. Favor low-residue meals around "
            + "your run and ease off raw, insoluble fiber today. If anything persists or you notice "
            + "bleeding, check in with your doctor."
        ),
      ])
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(.coachBackground)
  }
}

/// Wraps catalog content in a surface card (card radius + `spaceLg` padding) so the eyebrow sections show
/// on their real product surface (the brief card) rather than the sunken background.
@ViewBuilder
private func narrativeSectionCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
