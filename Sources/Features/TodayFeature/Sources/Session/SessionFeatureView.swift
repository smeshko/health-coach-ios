import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The daily session surface (`Row.png` / `Today · Exercise.png`) — the `DesignSystem` `SessionCard` for the
/// **displayed** session (narrative in-card, zone bar reflecting `displayedZoneRange`), with the footer
/// affordances wired and the **inline SWAP TO / SWAPPED TO list** drawn beneath the card when expanded.
///
/// A plain store-driven view (not the `@ViewAction` macro): it sends the flat `SessionFeature` actions. The
/// card stays pure — it renders labels and forwards taps through the injected `onSwap`/`onSkip` slots; the
/// expansion flag, the list, and the toggle select/revert live here.
public struct SessionFeatureView: View {
  @Bindable var store: StoreOf<SessionFeature>

  public init(store: StoreOf<SessionFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      SessionCard(
        store.displayedSession,
        zoneRange: store.displayedZoneRange,
        narrative: store.narrative,
        // The card shows "Swap ›" only when its `onSwap` is non-nil (alternatives exist) and the warm
        // "Skipping is fine today" only when `onSkip` is non-nil (`skipOk`). A rest-day session renders the
        // card's own "Rest is training too." footer and ignores both slots.
        onSwap: store.alternatives.isEmpty ? nil : { store.send(.swapToggled) },
        onSkip: store.skipOk ? { store.send(.skipTapped) } : nil
      )

      // The inline swap panel — SWAP TO, or SWAPPED TO once an alternative is selected; collapsing keeps
      // the swap (the reducer's independent expansion/selection state).
      if store.isSwapExpanded {
        SwapList(
          alternatives: store.alternatives,
          selectedIndex: store.selectedAlternativeIndex,
          onTap: { store.send(.alternativeTapped(index: $0)) }
        )
      }
    }
  }
}

/// The inline alternatives panel beneath the card — a header that flips SWAP TO → SWAPPED TO once a row is
/// selected, then one tappable `SwapRow` per alternative. The container + header derivation live here (the
/// feature), not in the pure card.
private struct SwapList: View {
  let alternatives: [SessionBlock]
  let selectedIndex: Int?
  let onTap: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      Text(selectedIndex == nil ? "SWAP TO" : "SWAPPED TO")
        .font(.coachText2xs)
        .tracking(Metrics.eyebrowTracking)
        .foregroundStyle(.coachForegroundMuted)

      ForEach(Array(alternatives.enumerated()), id: \.offset) { offset, block in
        Button { onTap(offset) } label: {
          SwapRow(block: block, isSelected: offset == selectedIndex)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
        .fill(.coachSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .stroke(.coachBorder, lineWidth: 1)
        )
    )
  }
}

/// One alternatives row — a type `IconBadge` (the session's intensity icon, a public `DisplayIconed`
/// accessor — no duplicated card-icon map), the `Card.label` title, and a model-backed "40 min · Low Impact"
/// sub-line (duration window + the flags' `DisplayLabel`s, falling back to the intensity label). The
/// **selected** row carries the soft-accent fill + a leading-checkmark trailing cue (the SWAPPED TO state).
private struct SwapRow: View {
  let block: SessionBlock
  let isSelected: Bool

  var body: some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      IconBadge(block.intensity.iconName, shape: .square, size: .sm, tone: .accent)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(block.card.label)
          .font(.coachTextMd)
          .foregroundStyle(.coachForeground)
        Text(subtitle)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundMuted)
      }
      Spacer(minLength: CoachSpacing.spaceSm)
      if isSelected {
        Image(systemName: "checkmark")
          .font(.coachTextSm)
          .foregroundStyle(.coachAccent)
      }
    }
    .padding(CoachSpacing.spaceSm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.sm, style: .continuous)
        .fill(isSelected ? Tone.accent.fill : .coachBackground)
    )
  }

  /// "40 min · Low Impact" — the duration window (collapsing when bounds match) + the session's flag
  /// `DisplayLabel`s, falling back to the intensity label when there are no flags. Model-backed, no raw key.
  private var subtitle: String {
    let duration = block.durationMinLow == block.durationMinHigh
      ? "\(block.durationMinLow) min"
      : "\(block.durationMinLow)–\(block.durationMinHigh) min"
    let descriptor = block.flags.isEmpty
      ? block.intensity.label
      : block.flags.map(\.label).joined(separator: " · ")
    return "\(duration) · \(descriptor)"
  }
}

/// Named constant — the SWAP TO / SWAPPED TO eyebrow's letter tracking (matches the readiness eyebrow).
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.8
}
