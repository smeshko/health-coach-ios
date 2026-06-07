import DesignSystem
import SwiftUI

/// Design System → Typography. Every `Font.coach…` token as a sample line with its name + role,
/// driven by a single `(name, role, font)` list.
struct TypographyGalleryPage: View {
  private struct Sample: Identifiable {
    var id: String { name }
    let name: String
    let role: String
    let font: Font
  }

  private let samples: [Sample] = [
    Sample(name: "displayNumerals", role: "Readiness score", font: CoachFont.displayNumerals),
    Sample(name: "pageHero", role: "Page hero", font: CoachFont.pageHero),
    Sample(name: "screenTitle", role: "Screen title", font: CoachFont.screenTitle),
    Sample(name: "bandLabel", role: "Band label", font: CoachFont.bandLabel),
    Sample(name: "cardHeadline", role: "Card headline", font: CoachFont.cardHeadline),
    Sample(name: "coachNoteHeading", role: "Coach note heading", font: CoachFont.coachNoteHeading),
    Sample(name: "body", role: "Body copy", font: CoachFont.body),
    Sample(name: "secondaryMeta", role: "Secondary meta", font: CoachFont.secondaryMeta),
    Sample(name: "dataEmphasis", role: "Data emphasis", font: CoachFont.dataEmphasis),
    Sample(name: "caption", role: "Caption", font: CoachFont.caption),
    Sample(name: "eyebrow", role: "Eyebrow", font: CoachFont.eyebrow),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.space16) {
        ForEach(samples) { sample in
          VStack(alignment: .leading, spacing: CoachSpacing.space2) {
            Text(sample.role).font(sample.font).foregroundStyle(CoachColor.foreground)
            Text(sample.name).font(CoachFont.caption).foregroundStyle(CoachColor.foregroundSubtle)
          }
        }
      }
      .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
    .navigationTitle("Typography")
  }
}
