import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The daily session surface (`Today · Exercise.png`) — a horizontal **paged carousel** of the candidate
/// `SessionCard`s (`[session] + alternatives`): swipe to browse (a neighbour card peeks), **tap a card to
/// commit** it as today's pick (green outline), with pager dots tracking the scroll position. The primary is
/// candidate 0 ("Suggested"); the rest are "Alternative".
///
/// A plain store-driven view (not the `@ViewAction` macro). The card stays pure — it renders labels +
/// forwards the skip tap through `onSkip`; selection is the reducer's (`cardSelected`). **Tap-to-commit vs
/// scroll-to-browse** means the pager dots follow `scrollPosition` while the green outline follows
/// `selectedIndex` — intentionally decoupled (DECISIONS D1). A lone candidate renders one full-width card
/// with no dots and no role eyebrow (RESEARCH resolution).
public struct SessionFeatureView: View {
  @Bindable var store: StoreOf<SessionFeature>
  /// The carousel's currently-centered candidate — drives the pager dots. Seeded to the committed pick so
  /// the carousel opens on today's selection (the persisted index the parent restored).
  @State private var scrollPosition: Int?
  /// Ticks on every commit tap — the `.selection` haptic is user-action-scoped, so a silent re-seed (a 12.1
  /// background refresh) never fires it.
  @State private var tapCount = 0

  public init(store: StoreOf<SessionFeature>) {
    self.store = store
    _scrollPosition = State(initialValue: store.selectedIndex)
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.spaceMd) {
      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: CoachSpacing.spaceMd) {
          ForEach(Array(store.candidates.enumerated()), id: \.offset) { index, block in
            SessionCardButton(
              block: block,
              zoneRange: store.state.zoneRange(for: block),
              narrative: store.narrative,
              isSelected: index == store.selectedIndex,
              roleLabel: roleLabel(at: index),
              onSkip: store.skipOk ? { store.send(.skipTapped) } : nil,
              onSelect: {
                scrollPosition = index
                store.send(.cardSelected(index: index))
                tapCount += 1
              }
            )
            // Each card spans ~90% of the carousel so the neighbour peeks on the trailing edge; a lone
            // candidate spans the full width (no peek).
            .containerRelativeFrame(
              .horizontal, count: Metrics.columns,
              span: store.candidates.count > 1 ? Metrics.cardSpan : Metrics.columns,
              spacing: CoachSpacing.spaceMd
            )
            .id(index)
          }
        }
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrollPosition)
      .scrollIndicators(.hidden)

      if store.candidates.count > 1 {
        PagerDots(count: store.candidates.count, active: scrollPosition ?? store.selectedIndex)
      }
    }
    // Selection haptic on every commit tap — user-action-scoped (positional token snaps under Reduce Motion).
    .sensoryFeedback(.selection, trigger: tapCount)
  }

  /// The static role eyebrow for a candidate — index 0 is the coach's recommendation ("Suggested"), the rest
  /// are "Alternative". A lone candidate has no role to contrast, so it carries no eyebrow.
  private func roleLabel(at index: Int) -> String? {
    guard store.candidates.count > 1 else { return nil }
    return index == 0 ? "Suggested" : "Alternative"
  }
}

/// One carousel cell — the pure `SessionCard` wrapped in a full-card `Button` that commits the candidate on
/// tap. `.coachPressable` gives the press scale; the card's own inner skip `Button` keeps its own hit area.
private struct SessionCardButton: View {
  let block: SessionBlock
  let zoneRange: ZoneRange?
  let narrative: [NarrativeSection]
  let isSelected: Bool
  let roleLabel: String?
  let onSkip: (() -> Void)?
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      SessionCard(
        block,
        zoneRange: zoneRange,
        narrative: narrative,
        roleLabel: roleLabel,
        isSelected: isSelected,
        onSkip: onSkip
      )
    }
    .buttonStyle(.coachPressable)
  }
}

/// The carousel position indicator — one dot per candidate, the centered one a wider accent pill, the rest
/// muted dots. Reflects the **scroll position** (not the committed selection), decoupled per DECISIONS D1.
private struct PagerDots: View {
  let count: Int
  let active: Int

  var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == active ? Color.coachAccent : Color.coachBorder)
          .frame(width: index == active ? Metrics.activeDotWidth : Metrics.dotSize, height: Metrics.dotSize)
      }
    }
    .coachAnimation(.selection, value: active)
  }
}

/// Named carousel metrics — the peek grid (a candidate spans `cardSpan` of `columns` columns) and the pager
/// dot sizes; no inline literals.
private enum Metrics {
  static let columns = 10
  static let cardSpan = 9
  static let dotSize: CGFloat = 6
  static let activeDotWidth: CGFloat = 18
}
