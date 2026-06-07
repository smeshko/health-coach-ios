import SwiftUI

/// Full-width primary CTA — accent fill, `$on-accent` label, optional leading SF Symbol.
public struct PrimaryButton: View {
  public let title: String
  public let icon: String?
  public let action: () -> Void

  public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: CoachSpacing.space8) {
        if let icon {
          Image(systemName: icon)
        }
        Text(title)
      }
      .font(CoachFont.cardHeadline)
      .foregroundStyle(CoachColor.onAccent)
      .frame(maxWidth: .infinity)
      .frame(height: ComponentMetrics.primaryButtonHeight)
      .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(CoachColor.accent))
    }
    .buttonStyle(.plain)
  }
}

/// Bordered ghost variant — transparent fill, 1px border, muted label.
public struct SecondaryButton: View {
  public let title: String
  public let icon: String?
  public let action: () -> Void

  public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: CoachSpacing.space8) {
        if let icon {
          Image(systemName: icon)
        }
        Text(title)
      }
      .font(CoachFont.secondaryMeta)
      .foregroundStyle(CoachColor.foregroundMuted)
      .frame(maxWidth: .infinity)
      .frame(height: ComponentMetrics.secondaryButtonHeight)
      .background(
        RoundedRectangle(cornerRadius: CoachRadius.md).stroke(CoachColor.border, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}
