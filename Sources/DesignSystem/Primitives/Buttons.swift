import SwiftUI

/// Full-width primary CTA — accent fill, `$on-accent` label, optional leading SF Symbol.
public struct PrimaryButton: View {
  let title: String
  let icon: String?
  let action: () -> Void

  public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: CoachSpacing.spaceXs) {
        if let icon {
          Image(systemName: icon)
        }
        Text(title)
      }
      .font(.coachTextLg)
      .foregroundStyle(.coachOnAccent)
      .frame(maxWidth: .infinity)
      .frame(height: Metrics.primaryButtonHeight)
      .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(.coachAccent))
    }
    .buttonStyle(.plain)
  }
}

/// Bordered ghost variant — transparent fill, 1px border, muted label.
public struct SecondaryButton: View {
  let title: String
  let icon: String?
  let action: () -> Void

  public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: CoachSpacing.spaceXs) {
        if let icon {
          Image(systemName: icon)
        }
        Text(title)
      }
      .font(.coachTextSm)
      .foregroundStyle(.coachForegroundMuted)
      .frame(maxWidth: .infinity)
      .frame(height: Metrics.secondaryButtonHeight)
      .background(
        RoundedRectangle(cornerRadius: CoachRadius.md).stroke(.coachBorder, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

/// Control heights (HIG-comfortable tap targets) — named constants, not inline literals.
private enum Metrics {
  static let primaryButtonHeight: CGFloat = 54
  static let secondaryButtonHeight: CGFloat = 54
}
