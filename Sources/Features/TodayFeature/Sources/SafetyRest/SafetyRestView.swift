import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The distinct **calm forced-REST screen** (`Today · Exercise — Off day` calm treatment, PRD §7.4.2 /
/// §9.2): the mapped calm reason headline as a set-apart **soft-accent** block (never the red-alert
/// token), and the deterministic override session presented as the **positive action** via a read-only
/// `SessionCard` — **no swap, no skip, no alternatives** (those are structurally absent, not hidden: a
/// forced rest forbids them, and the empty `alternatives` are never rendered here).
///
/// The readiness gauge sits **above** this view (the parent composes it once over both the forced-REST and
/// normal branches — see [[TodaySessionMode]] / the parent `ready` switch). The `narrative` is the
/// parent-filtered session/caution slice, rendered **verbatim** inside the card by `NarrativeRenderer`
/// (principle #1) — this view authors no coaching prose; the calm reason headline is fixed §7.4.2 UX copy.
///
/// `store.overrideSession` is the expanded `brief.session` (`SessionBlock`), **not** `gate.overrideTo` (a
/// `Card?`). `store.zoneRange` (parent-supplied) feeds the override card's zone chip; `nil` ⇒ no chip
/// (true for the `rest`/`mobility` overrides). The view never resolves zones itself (§3).
public struct SafetyRestView: View {
  let store: StoreOf<SafetyRestComponent>
  /// The session/caution narrative slice for the override card, parent-filtered. Rendered verbatim.
  let narrative: [NarrativeSection]

  public init(store: StoreOf<SafetyRestComponent>, narrative: [NarrativeSection] = []) {
    self.store = store
    self.narrative = narrative
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // The calm reason — the §7.4.2 sentence(s) in the shared soft-accent "forced-rest echo" callout
      // (InsetCallout `.raised`). Soft accent + a heart icon read as good coaching, never an alarm
      // (PRD §9.2 — never the red band token).
      InsetCallout(
        icon: "heart.fill",
        tone: .accent,
        headline: "Recovery day",
        content: store.reasonHeadlines.joined(separator: " "),
        surface: .raised
      )

      // The override session as the positive action — read-only: no `onSwap`/`onSkip` injected, so the
      // card's footer affordances stay empty (the forbidden swap/skip are structurally absent).
      SessionCard(store.overrideSession, zoneRange: store.zoneRange, narrative: narrative)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
