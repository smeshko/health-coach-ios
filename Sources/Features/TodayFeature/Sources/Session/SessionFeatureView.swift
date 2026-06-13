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
  /// Ticks on every swap-row tap — select AND tap-again-revert are both user selections (Phase 12.3, D4).
  /// Keyed on the tap, not `selectedAlternativeIndex` (which a fresh-brief re-seed also resets), so a
  /// programmatic re-seed stays silent.
  @State private var swapTapCount = 0

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
      // Identity-keyed crossfade of the card's content (Phase 12.3, TASK-004): `SessionCard` is
      // non-animatable `Text`s + conditional rest/zone/effort branches, so a bare animation transaction
      // would snap them. Re-`.id` on the content discriminant + `.transition(.opacity)` crossfades the whole
      // card on a swap tap AND on a 12.1 background re-seed that changes the session. `.opacity` stays valid
      // under Reduce Motion's snap fallback (a same-card/zone sub-field-only change leaves `.id` unchanged →
      // a documented accepted snap).
      .id(store.displayedCardID)
      .transition(.opacity)

      // The inline swap panel — SWAP TO, or SWAPPED TO once an alternative is selected; collapsing keeps
      // the swap (the reducer's independent expansion/selection state). Enters/leaves with a slide-from-top
      // crossfade under the `disclosure` animation below.
      if store.isSwapExpanded {
        SwapList(
          rows: store.alternativeRows,
          selectedIndex: store.selectedAlternativeIndex,
          onTap: {
            store.send(.alternativeTapped(index: $0))
            swapTapCount += 1
          }
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    // Both animations attach to this surviving ancestor VStack, not the conditional `SwapList` (on which a
    // collapse would silently snap): `disclosure` drives the panel expand/collapse; `selection` drives the
    // in-place row highlight + the card's identity crossfade, keyed on the SAME `displayedCardID` as the
    // card's `.id` so a swap tap, a tap-again-revert, and a 12.1 re-seed all carry a transaction (Phase
    // 12.3, view-scoped per D2; positional tokens → snap under Reduce Motion).
    .coachAnimation(.disclosure, value: store.isSwapExpanded)
    .coachAnimation(.selection, value: store.displayedCardID)
    // Selection tick on every swap-row tap (select + revert) — user-action-scoped (D4).
    .sensoryFeedback(.selection, trigger: swapTapCount)
  }
}

/// The inline alternatives panel beneath the card — a header that flips SWAP TO → SWAPPED TO once a row is
/// selected, then one tappable `SwapRow` per alternative. The container + header derivation live here (the
/// feature), not in the pure card.
private struct SwapList: View {
  /// The identity-stable row projection (Phase 12.3, DECISIONS D3) — `ForEach(rows)` reads declaratively;
  /// selection changes a row's content, never its identity, so the highlight animates in place.
  let rows: [SessionFeature.AlternativeRow]
  let selectedIndex: Int?
  let onTap: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      Text(selectedIndex == nil ? "SWAP TO" : "SWAPPED TO")
        .font(.coachText2xs)
        .tracking(Metrics.eyebrowTracking)
        .foregroundStyle(.coachForegroundMuted)

      ForEach(rows) { row in
        Button { onTap(row.id) } label: {
          SwapRow(block: row.block, isSelected: row.id == selectedIndex)
        }
        .buttonStyle(.coachPressable)
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
    // Derived from `durationRange` (clamped) so inverted server bounds render a normalized window,
    // never a backwards `55–40 min` (Phase 11.6 audit production finding 3).
    let range = block.durationRange
    let duration = range.lowerBound == range.upperBound
      ? "\(range.lowerBound) min"
      : "\(range.lowerBound)–\(range.upperBound) min"
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
