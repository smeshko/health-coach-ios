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

  @Binding var selection: Tab

  public init(selection: Binding<Tab>) {
    _selection = selection
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      ForEach(Tab.allCases, id: \.self) { tab in
        Segment(tab: tab, selection: $selection)
      }
    }
    .padding(CoachSpacing.space2xs)
    .background(Capsule().fill(.coachBorder))
  }

  /// One segment — an icon-over-label button; the active segment raises to a surface fill.
  private struct Segment: View {
    let tab: Tab
    @Binding var selection: Tab

    var body: some View {
      let isActive = tab == selection
      Button {
        selection = tab
      } label: {
        HStack(spacing: CoachSpacing.spaceXs) {
          Image(systemName: tab.icon).font(.system(size: 16, weight: .semibold))
          Text(tab.label).font(.coachTextSm)
        }
        .foregroundStyle(isActive ? .coachForeground : .coachForegroundMuted)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.segmentHeight)
        .background(Capsule().fill(isActive ? .coachSurfaceRaised : Color.clear))
      }
      .buttonStyle(.plain)
    }
  }
}

/// Segment control height — a named constant, not an inline literal.
private enum Metrics {
  static let segmentHeight: CGFloat = 36
}
