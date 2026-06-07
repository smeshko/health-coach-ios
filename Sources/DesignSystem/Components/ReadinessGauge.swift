import DomainModels
import SwiftUI

/// The daily readiness gauge — the score, the band **color token** paired with the band **label + icon**
/// (color is never the sole signal, §9.4), the band bar, and a **"why" affordance hook**. The actual
/// penalty breakdown is the feature's (Epic 7.2): this exposes a `onWhyTapped` callback + an optional
/// `isWhyExpanded` binding only. Composes the `ReadinessBar` primitive + the 5.1 `ReadinessBand` tokens.
public struct ReadinessGauge: View {
  public let readiness: Readiness
  @Binding public var isWhyExpanded: Bool
  public let onWhyTapped: () -> Void

  public init(
    readiness: Readiness,
    isWhyExpanded: Binding<Bool> = .constant(false),
    onWhyTapped: @escaping () -> Void = {}
  ) {
    self.readiness = readiness
    _isWhyExpanded = isWhyExpanded
    self.onWhyTapped = onWhyTapped
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space16) {
      HStack(alignment: .center, spacing: CoachSpacing.space12) {
        Text("\(readiness.score)")
          .font(CoachFont.displayNumerals)
          .foregroundStyle(readiness.band.color)
        VStack(alignment: .leading, spacing: CoachSpacing.space2) {
          HStack(spacing: CoachSpacing.space6) {
            Image(systemName: readiness.band.iconName).foregroundStyle(readiness.band.color)
            Text(readiness.band.label)
              .font(CoachFont.cardHeadline)
              .foregroundStyle(CoachColor.foreground)
          }
          Text("Readiness").font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foregroundMuted)
        }
        Spacer(minLength: 0)
        whyButton
      }
      ReadinessBar(score: readiness.score)
    }
    .padding(CoachSpacing.space16)
    .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(CoachColor.surface))
    .overlay(RoundedRectangle(cornerRadius: CoachRadius.card).stroke(CoachColor.border, lineWidth: 1))
  }

  private var whyButton: some View {
    Button {
      isWhyExpanded.toggle()
      onWhyTapped()
    } label: {
      HStack(spacing: CoachSpacing.space2) {
        Text("Why").font(CoachFont.secondaryMeta)
        Image(systemName: isWhyExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold))
      }
      .foregroundStyle(CoachColor.accent)
    }
    .buttonStyle(.plain)
  }
}
