import SwiftUI

/// Full-width primary CTA — accent fill, `$on-accent` label, optional leading SF Symbol. When
/// `isLoading` is true the label is hidden behind a centered spinner (the accent fill stays) and taps
/// are blocked, so callers get a self-contained busy state instead of overlaying a `ProgressView`.
public struct PrimaryButton: View {
  let title: String
  let icon: String?
  let isLoading: Bool
  let action: () -> Void

  public init(
    _ title: String,
    icon: String? = nil,
    isLoading: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.isLoading = isLoading
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
      .opacity(isLoading ? 0 : 1)
      .frame(maxWidth: .infinity)
      .frame(height: Metrics.primaryButtonHeight)
      .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(.coachAccent))
      .overlay {
        if isLoading {
          ProgressView().tint(.coachOnAccent)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
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
