import DesignSystem
import SwiftUI

/// Design System → Typography. Mirrors the Typography reference: each of the nine scale tokens shown as
/// a sample line in its own font, with the token name, point size / weight, and role. One family — SF
/// Pro. A single `Sample` list drives the page.
struct TypographyGalleryPage: View {
  private struct Sample: Identifiable {
    var id: String { token }
    let sample: String
    let token: String
    let spec: String
    let font: Font
    var tracking: CGFloat = 0
  }

  private let samples: [Sample] = [
    Sample(sample: "78", token: "text-display", spec: "64 / Bold — hero numerals (readiness score)", font: CoachFont.textDisplay),
    Sample(sample: "Coach", token: "text-3xl", spec: "40 / Bold — page hero", font: CoachFont.text3xl),
    Sample(sample: "Today", token: "text-2xl", spec: "30 / Bold — screen title", font: CoachFont.text2xl),
    Sample(sample: "Ready", token: "text-xl", spec: "24 / Bold — section & card headline", font: CoachFont.textXl),
    Sample(sample: "Good morning", token: "text-lg", spec: "17 / Semibold — headings & card names", font: CoachFont.textLg),
    Sample(sample: "You are recovered and clear to train.", token: "text-md", spec: "15 / Regular — body & narrative", font: CoachFont.textMd),
    Sample(sample: "35–45 min", token: "text-sm", spec: "13 / Semibold — data & secondary meta", font: CoachFont.textSm),
    Sample(sample: "keep HR ≤146 bpm", token: "text-xs", spec: "12 / Medium — captions & chips", font: CoachFont.textXs),
    Sample(sample: "READINESS", token: "text-2xs", spec: "11 / Bold — eyebrows & micro labels", font: CoachFont.text2xs, tracking: 1.5),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text("Nine scale-based sizes, four weights. One family — SF Pro. Bind fontSize + fontWeight to tokens, never raw numbers.")
          .font(CoachFont.textMd)
          .foregroundStyle(CoachColor.foregroundMuted)

        ForEach(samples) { sample in
          VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
            Text(sample.sample)
              .font(sample.font)
              .tracking(sample.tracking)
              .foregroundStyle(CoachColor.foreground)
            Text("\(sample.token) · \(sample.spec)")
              .font(CoachFont.textXs)
              .foregroundStyle(CoachColor.foregroundSubtle)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Typography")
  }
}
