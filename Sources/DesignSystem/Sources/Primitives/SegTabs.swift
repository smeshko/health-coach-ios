import SwiftUI

/// A two-option segmented switcher (Exercise / Nutrition) for sibling views. Selection lives with the
/// caller via `@Binding`. The active segment is highlighted by a **single** raised-surface capsule that
/// *slides* between segments via `matchedGeometryEffect` (the canonical segmented-control pattern) — it
/// lives in the stack's background layer so segment frames stay fixed and only the highlight's geometry
/// animates. Slide uses the `selection` motion token; under Reduce Motion that token resolves to `nil`
/// so the highlight snaps (no positional motion — the pre-phase behavior). A selection haptic fires on
/// every change regardless of Reduce Motion.
public struct SegTabs: View {
  @Namespace private var highlightNamespace
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
        Segment(tab: tab, isActive: tab == selection, namespace: highlightNamespace) {
          selection = tab
        }
      }
    }
    .coachAnimation(.selection, value: selection)
    .padding(CoachSpacing.space2xs)
    .background(Capsule().fill(.coachBorder))
    .sensoryFeedback(.selection, trigger: selection)
  }

  /// One segment — an icon-over-label button. Only the *active* segment draws the shared highlight
  /// capsule (via `matchedGeometryEffect`), so the single capsule slides between segments rather than
  /// re-mounting. Segment frames are fixed (`maxWidth: .infinity` + a fixed height) so only the
  /// highlight's geometry animates.
  private struct Segment: View {
    let tab: Tab
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        HStack(spacing: CoachSpacing.spaceXs) {
          Image(systemName: tab.icon).font(.system(size: 16, weight: .semibold))
          Text(tab.label).font(.coachTextSm)
        }
        .foregroundStyle(isActive ? .coachForeground : .coachForegroundMuted)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.segmentHeight)
        .background {
          if isActive {
            Capsule()
              .fill(.coachSurfaceRaised)
              .matchedGeometryEffect(id: Self.highlightID, in: namespace)
          }
        }
      }
      .buttonStyle(.coachPressable)
    }

    private static let highlightID = "segtabs-highlight"
  }
}

/// Segment control height — a named constant, not an inline literal.
private enum Metrics {
  static let segmentHeight: CGFloat = 36
}
