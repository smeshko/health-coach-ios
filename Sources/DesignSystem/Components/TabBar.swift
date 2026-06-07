import SwiftUI

/// A floating glass bottom nav — Today / Week / Trends / You. The selected tab gets a `$tab-selected`
/// capsule + `$accent` icon/label; unselected are `$fg-subtle`. Selection lives with the caller.
public struct TabBar: View {
  public enum Tab: String, CaseIterable, Sendable {
    case today
    case week
    case trends
    case you

    var label: String {
      switch self {
      case .today: "Today"
      case .week: "Week"
      case .trends: "Trends"
      case .you: "You"
      }
    }

    var icon: Icon {
      switch self {
      case .today: .today
      case .week: .week
      case .trends: .trends
      case .you: .you
      }
    }
  }

  @Binding public var selection: Tab

  public init(selection: Binding<Tab>) {
    _selection = selection
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space2) {
      ForEach(Tab.allCases, id: \.self) { tab in
        item(tab)
      }
    }
    .frame(height: ComponentMetrics.tabBarHeight)
    .padding(CoachSpacing.space4)
    .background(Capsule().fill(CoachColor.surfaceGlass))
    .overlay(Capsule().stroke(CoachColor.border, lineWidth: 1))
    .shadow(color: CoachColor.shadow, radius: 16, y: 4)
    .padding(.top, CoachSpacing.space12)
    .padding(.horizontal, CoachSpacing.space24)
    .padding(.bottom, CoachSpacing.space24)
  }

  private func item(_ tab: Tab) -> some View {
    let isActive = tab == selection
    return Button {
      selection = tab
    } label: {
      VStack(spacing: CoachSpacing.space2) {
        Image(systemName: tab.icon.systemName).font(.system(size: 20))
        Text(tab.label).font(.system(size: 10, weight: .semibold))
      }
      .foregroundStyle(isActive ? CoachColor.accent : CoachColor.foregroundSubtle)
      .frame(maxWidth: .infinity)
      .padding(.vertical, CoachSpacing.space8)
      .background(isActive ? Capsule().fill(CoachColor.tabSelected) : Capsule().fill(Color.clear))
    }
    .buttonStyle(.plain)
  }
}
