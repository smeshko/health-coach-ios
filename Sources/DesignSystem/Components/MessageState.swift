import SwiftUI

/// A generic centered full-screen state — empty / error / success / reconnect. The icon + tone encode
/// the semantics (icon circle in the tone's soft tint + strong foreground).
public struct MessageState: View {
  /// A primary call-to-action.
  public struct Primary {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
      self.title = title
      self.icon = icon
      self.action = action
    }
  }

  public let icon: String
  public let tone: Tone
  public let title: String
  public let message: String
  public let primary: Primary?
  public let secondaryTitle: String?
  public let secondaryAction: () -> Void

  public init(
    icon: String,
    tone: Tone = .negative,
    title: String,
    body: String,
    primary: Primary? = nil,
    secondaryTitle: String? = nil,
    secondaryAction: @escaping () -> Void = {}
  ) {
    self.icon = icon
    self.tone = tone
    self.title = title
    message = body
    self.primary = primary
    self.secondaryTitle = secondaryTitle
    self.secondaryAction = secondaryAction
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.space24) {
      Image(systemName: icon)
        .font(.system(size: 34))
        .foregroundStyle(tone.foreground)
        .frame(width: ComponentMetrics.messageIconCircle, height: ComponentMetrics.messageIconCircle)
        .background(Circle().fill(tone.fill))
      VStack(spacing: CoachSpacing.space8) {
        Text(title).font(.system(size: 23, weight: .bold)).foregroundStyle(CoachColor.foreground)
        Text(message)
          .font(CoachFont.secondaryMeta)
          .foregroundStyle(CoachColor.foregroundMuted)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 300)
      }
      if let primary {
        PrimaryButton(primary.title, icon: primary.icon, action: primary.action)
          .padding(.horizontal, CoachSpacing.space24)
      }
      if let secondaryTitle {
        Button(secondaryTitle, action: secondaryAction)
          .font(CoachFont.secondaryMeta)
          .foregroundStyle(CoachColor.foregroundMuted)
          .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(CoachSpacing.space24)
    .background(CoachColor.background)
  }
}
