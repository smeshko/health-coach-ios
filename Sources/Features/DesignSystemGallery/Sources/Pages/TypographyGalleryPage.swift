import DesignSystem
import SwiftUI

/// Design System → Typography. Mirrors the Typography reference: each of the nine scale tokens shown as
/// a sample line in its own font, with the token name, point size / weight, and role. One family — SF
/// Pro.
///
/// The nine samples are taller than the device frame, so they are split into two device-fitting
/// sections (`TypographyLargeSection` — the five display/heading sizes; `TypographyBodySection` — the
/// four body/meta sizes) which the page stacks and the snapshot tests render directly (so nothing
/// clips below the fold).
struct TypographyGalleryPage: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text("Nine scale-based sizes, four weights. One family — SF Pro. "
          + "Bind fontSize + fontWeight to tokens, never raw numbers.")
          .font(CoachFont.textMd)
          .foregroundStyle(CoachColor.foregroundMuted)

        TypographyLargeSection()
        TypographyBodySection()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Typography")
  }
}

/// One type-scale sample — data, not a view.
struct TypeSample: Identifiable {
  var id: String { token }
  let sample: String
  let token: String
  let spec: String
  let font: Font
  var tracking: CGFloat = 0
}

/// The five display + heading sizes (text-display … text-lg).
let typographyLargeSamples: [TypeSample] = [
  TypeSample(sample: "78", token: "text-display", spec: "64 / Bold — hero numerals (readiness score)",
             font: CoachFont.textDisplay),
  TypeSample(sample: "Coach", token: "text-3xl", spec: "40 / Bold — page hero",
             font: CoachFont.text3xl),
  TypeSample(sample: "Today", token: "text-2xl", spec: "30 / Bold — screen title",
             font: CoachFont.text2xl),
  TypeSample(sample: "Ready", token: "text-xl", spec: "24 / Bold — section & card headline",
             font: CoachFont.textXl),
  TypeSample(sample: "Good morning", token: "text-lg", spec: "17 / Semibold — headings & card names",
             font: CoachFont.textLg),
]

/// The four body + meta sizes (text-md … text-2xs).
let typographyBodySamples: [TypeSample] = [
  TypeSample(sample: "You are recovered and clear to train.", token: "text-md", spec: "15 / Regular — body & narrative",
             font: CoachFont.textMd),
  TypeSample(sample: "35–45 min", token: "text-sm", spec: "13 / Semibold — data & secondary meta",
             font: CoachFont.textSm),
  TypeSample(sample: "keep HR ≤146 bpm", token: "text-xs", spec: "12 / Medium — captions & chips",
             font: CoachFont.textXs),
  TypeSample(sample: "READINESS", token: "text-2xs", spec: "11 / Bold — eyebrows & micro labels",
             font: CoachFont.text2xs, tracking: 1.5),
]

/// The display + heading sizes — a device-fitting section.
struct TypographyLargeSection: View {
  var body: some View {
    typeSampleColumn(typographyLargeSamples)
  }
}

/// The body + meta sizes — a device-fitting section.
struct TypographyBodySection: View {
  var body: some View {
    typeSampleColumn(typographyBodySamples)
  }
}

private func typeSampleColumn(_ samples: [TypeSample]) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
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
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .padding(CoachSpacing.spaceMd)
  .background(CoachColor.background)
}
