import SwiftUI

/// A two-option segmented switcher (Exercise / Nutrition) for sibling views. Selection lives with the
/// caller via `@Binding`; the active segment is a raised surface with an accent icon.
public struct SegTabs: View {
  public enum Tab: String, CaseIterable, Sendable {
    case exercise
    case nutrition

    var label: String {
      switch self {
      case .exercise: "Exercise"
      case .nutrition: "Nutrition"
      }
    }

    var icon: String {
      switch self {
      case .exercise: Icon.exercise.systemName
      case .nutrition: Icon.nutrition.systemName
      }
    }
  }

  @Binding public var selection: Tab

  public init(selection: Binding<Tab>) {
    _selection = selection
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space6) {
      ForEach(Tab.allCases, id: \.self) { tab in
        segment(tab)
      }
    }
    .padding(CoachSpacing.space4)
    .background(Capsule().fill(CoachColor.border))
  }

  private func segment(_ tab: Tab) -> some View {
    let isActive = tab == selection
    return Button {
      selection = tab
    } label: {
      HStack(spacing: CoachSpacing.space6) {
        Image(systemName: tab.icon).font(.system(size: 16, weight: .semibold))
        Text(tab.label).font(CoachFont.secondaryMeta)
      }
      .foregroundStyle(isActive ? CoachColor.foreground : CoachColor.foregroundMuted)
      .frame(maxWidth: .infinity)
      .frame(height: ComponentMetrics.segmentHeight)
      .background(Capsule().fill(isActive ? CoachColor.surfaceRaised : Color.clear))
    }
    .buttonStyle(.plain)
  }
}
