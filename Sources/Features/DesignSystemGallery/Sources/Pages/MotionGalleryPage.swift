import DesignSystem
import SwiftUI

/// Design System → Motion. Documents the `CoachMotion` vocabulary: a static token table (class /
/// domain / spring / Reduce-Motion fallback, mirroring `SpacingGalleryPage`'s shape) plus **live
/// demos** — a pressable button row, a `SegTabs` instance (slide + haptic), and a `disclosure`-token
/// expand/collapse. The live demos stay out of the snapshotted section (`MotionTokenTableSection`) so
/// snapshots remain animation-deterministic; toggling Reduce Motion in Settings on the sim is the manual
/// check for the snap-not-slide behavior.
struct MotionGalleryPage: View {
  @State private var segSelection: SegTabs.Tab = .exercise
  @State private var isExpanded = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text(
          "Each interaction class is a token: a spring for full motion plus an explicit Reduce-Motion "
            + "fallback (positional classes snap; opacity classes crossfade). Components resolve a token "
            + "through CoachMotion.animation(_:reduceMotion:) — never raw spring parameters."
        )
        .font(CoachFont.textMd)
        .foregroundStyle(CoachColor.foregroundMuted)

        MotionTokenTableSection()

        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          eyebrow("Live · pressable (press to scale + dim)")
          HStack(spacing: CoachSpacing.spaceMd) {
            PrimaryButton("Press me") {}
            SecondaryButton("And me") {}
          }
        }

        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          eyebrow("Live · selection (tap to slide the highlight)")
          SegTabs(selection: $segSelection)
        }

        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          eyebrow("Live · disclosure (tap to expand/collapse)")
          Button { isExpanded.toggle() } label: {
            HStack {
              Text(isExpanded ? "Hide detail" : "Show detail")
              Spacer()
              Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .font(CoachFont.textMd)
            .foregroundStyle(CoachColor.accent)
          }
          .buttonStyle(.coachPressable)
          if isExpanded {
            Text("Expand/collapse runs on the disclosure token; under Reduce Motion it snaps instantly.")
              .font(CoachFont.textSm)
              .foregroundStyle(CoachColor.foregroundMuted)
          }
        }
        .coachAnimation(.disclosure, value: isExpanded)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Motion")
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
  }
}

/// The static `CoachMotion` token table — a device-fitting section snapshotted directly (the live demos
/// above animate, so they're excluded to keep the snapshot deterministic).
struct MotionTokenTableSection: View {
  private struct Row: Identifiable {
    var id: String { token }
    let token: String
    let domain: String
    let spring: String
    let fallback: String
  }

  private let rows: [Row] = [
    Row(token: "selection", domain: "positional", spring: "0.30s · bounce 0.2", fallback: "nil (snap)"),
    Row(token: "disclosure", domain: "positional", spring: "0.35s · bounce 0", fallback: "nil (snap)"),
    Row(token: "screenChange", domain: "opacity", spring: "0.40s · bounce 0", fallback: "easeInOut 0.2s"),
    Row(token: "pressed", domain: "opacity+scale", spring: "0.20s · bounce 0", fallback: "easeInOut 0.2s"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Text("Token table")
        .font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
      ForEach(rows) { row in
        VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
          HStack {
            Text(row.token).font(CoachFont.textLg).foregroundStyle(CoachColor.foreground)
            Spacer(minLength: 0)
            Text(row.domain).font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundSubtle)
          }
          HStack(spacing: CoachSpacing.spaceMd) {
            Text("spring \(row.spring)")
              .font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundMuted)
            Spacer(minLength: 0)
            Text("RM → \(row.fallback)")
              .font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundMuted)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CoachSpacing.spaceSm)
        .background(
          RoundedRectangle(cornerRadius: CoachRadius.sm, style: .continuous).fill(CoachColor.surface)
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(CoachColor.background)
  }
}
