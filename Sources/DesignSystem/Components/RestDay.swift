import SwiftUI

/// A full-screen forced-rest state — the reason for the rest day + a light-activity primary action and
/// a "stay fully restful" secondary. All copy is swappable per rest reason (defaults to gut-flare).
public struct RestDay: View {
  public let eyebrow: String
  public let headline: String
  public let bodyText: String
  public let signalIcon: String
  public let signalLabel: String
  public let signalValue: String
  public let primaryTitle: String
  public let primarySub: String

  public init(
    eyebrow: String = "REST DAY",
    headline: String = "Take it easy today",
    body: String = "Your gut needs a break. Skipping the session today protects tomorrow's training.",
    signalIcon: String = Icon.drop.systemName,
    signalLabel: String = "Reason",
    signalValue: String = "GI flare",
    primaryTitle: String = "Light mobility · 10 min",
    primarySub: String = "Gentle movement, no load"
  ) {
    self.eyebrow = eyebrow
    self.headline = headline
    bodyText = body
    self.signalIcon = signalIcon
    self.signalLabel = signalLabel
    self.signalValue = signalValue
    self.primaryTitle = primaryTitle
    self.primarySub = primarySub
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.space18) {
      top
      Spacer(minLength: 0)
      bottom
    }
    .padding(.horizontal, CoachSpacing.space24)
    .padding(.vertical, CoachSpacing.space16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CoachColor.background)
  }

  private var top: some View {
    VStack(spacing: CoachSpacing.space12) {
      Image(systemName: Icon.restHero.systemName)
        .font(.system(size: 40))
        .foregroundStyle(CoachColor.accent)
        .frame(width: ComponentMetrics.restIconCircle, height: ComponentMetrics.restIconCircle)
        .background(Circle().fill(CoachColor.accentSoft))
      Text(eyebrow).font(CoachFont.eyebrow).tracking(1.6).foregroundStyle(CoachColor.accent)
      Text(headline)
        .font(.system(size: 26, weight: .bold))
        .multilineTextAlignment(.center)
        .foregroundStyle(CoachColor.foreground)
      Text(bodyText)
        .font(CoachFont.secondaryMeta)
        .multilineTextAlignment(.center)
        .foregroundStyle(CoachColor.foregroundMuted)
      signalCard
    }
  }

  private var signalCard: some View {
    HStack(spacing: CoachSpacing.space12) {
      Image(systemName: signalIcon)
        .foregroundStyle(CoachColor.accent)
        .frame(width: 40, height: 40)
        .background(RoundedRectangle(cornerRadius: CoachRadius.sm).fill(CoachColor.accentSoft))
      VStack(alignment: .leading, spacing: CoachSpacing.space2) {
        Text(signalLabel).font(CoachFont.dataEmphasis).foregroundStyle(CoachColor.foregroundSubtle)
        Text(signalValue).font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foreground)
      }
      Spacer(minLength: 0)
    }
    .padding(CoachSpacing.space12)
    .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(CoachColor.surface))
    .overlay(RoundedRectangle(cornerRadius: CoachRadius.md).stroke(CoachColor.border, lineWidth: 1))
  }

  private var bottom: some View {
    VStack(spacing: CoachSpacing.space12) {
      primaryRow
      SecondaryButton("Keep today fully restful") {}
      Text("You can always change your mind.")
        .font(CoachFont.caption)
        .foregroundStyle(CoachColor.foregroundSubtle)
    }
  }

  private var primaryRow: some View {
    HStack(spacing: CoachSpacing.space12) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2) {
        Text(primaryTitle).font(CoachFont.cardHeadline).foregroundStyle(CoachColor.onAccent)
        Text(primarySub).font(CoachFont.caption).foregroundStyle(CoachColor.onAccentMuted)
      }
      Spacer(minLength: 0)
      Image(systemName: Icon.arrowRight.systemName)
        .foregroundStyle(CoachColor.onAccent)
        .frame(width: 32, height: 32)
        .background(Circle().fill(CoachColor.onAccent.opacity(0.15)))
    }
    .padding(CoachSpacing.space16)
    .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(CoachColor.accent))
  }
}
