import DesignSystem
import DomainModels
import SwiftUI

/// The distinct **calm forced-REST screen** (`Today · Exercise — Off day` calm treatment, PRD §7.4.2 /
/// §9.2): the mapped calm reason headline as a set-apart **soft-accent** block (never the red-alert
/// token), and the deterministic override session presented as the **positive action** via a read-only
/// `SessionCard` — **no swap, no skip, no alternatives** (those are structurally absent, not hidden: a
/// forced rest forbids them, and the empty `alternatives` are never rendered here).
///
/// A **render-only** value-init view (no `@Reducer` ceremony — it owns no fetching and no in-screen
/// interaction): the parent constructs it from the loaded brief only on a trip (see [[TodaySessionMode]]).
/// `gate`, `overrideSession`, and `zoneRange` are a **pure derivation** from the brief — the tripped
/// `SafetyGate`, the expanded override `SessionBlock` (`brief.session`, *not* `gate.overrideTo`), and the
/// parent-supplied bpm `zoneRange` for the override card's zone chip.
///
/// The readiness gauge sits **above** this view (the parent composes it once over both the forced-REST and
/// normal branches — see [[TodaySessionMode]] / the parent `ready` switch). The `narrative` is the
/// parent-filtered session/caution slice, rendered **verbatim** inside the card by `NarrativeRenderer`
/// (principle #1) — this view authors no coaching prose; the calm reason headline is fixed §7.4.2 UX copy.
///
/// `overrideSession` is the expanded `brief.session` (`SessionBlock`), **not** `gate.overrideTo` (a
/// `Card?`). `zoneRange` (parent-supplied) feeds the override card's zone chip; `nil` ⇒ no chip
/// (true for the `rest`/`mobility` overrides). The view never resolves zones itself (§3).
///
/// **Feature dependency rule (§3):** imports only `DesignSystem` + `DomainModels` + `SwiftUI`. No
/// repository `@Dependency`, no `WireModels`/GRDB/HealthKit.
public struct SafetyRestView: View {
  /// The tripped gate (`triggered == true`, its `reasons`, the `overrideTo` *name*).
  let gate: DomainModels.SafetyGate
  /// The deterministic override session — the expanded `brief.session` (a `SessionBlock`), the rendered
  /// form of the gate's `overrideTo` card. **Not** `gate.overrideTo` (a `Card?`).
  let overrideSession: DomainModels.SessionBlock
  /// The bpm range for the override card's `ZoneChip`, **pre-resolved by the parent** from
  /// `ProfileRepository.zones()` (the view never resolves zones, §3). `nil` ⇒ no chip (true for
  /// `rest`/`mobility` overrides, whose `zoneTarget == nil`).
  let zoneRange: DomainModels.ZoneRange?
  /// The session/caution narrative slice for the override card, parent-filtered. Rendered verbatim.
  let narrative: [NarrativeSection]

  public init(
    gate: DomainModels.SafetyGate,
    overrideSession: DomainModels.SessionBlock,
    zoneRange: DomainModels.ZoneRange? = nil,
    narrative: [NarrativeSection] = []
  ) {
    self.gate = gate
    self.overrideSession = overrideSession
    self.zoneRange = zoneRange
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
        content: Self.reasonHeadlines(for: gate).joined(separator: " "),
        surface: .raised
      )

      // The override session as the positive action — read-only: no `onSwap`/`onSkip` injected, so the
      // card's footer affordances stay empty (the forbidden swap/skip are structurally absent).
      SessionCard(overrideSession, zoneRange: zoneRange, narrative: narrative)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The calm reason headline(s) — each `gate.reasons` element through the §7.4.2 typed calm-copy switch
  /// (the single translation point, principle #2). An empty/`.unknown` `reasons` list falls back to the
  /// generic graceful line, so the screen never shows a blank headline or a raw key.
  static func reasonHeadlines(for gate: DomainModels.SafetyGate) -> [String] {
    gate.reasons.isEmpty
      ? [SafetyReasonCopy.calmCopy(for: .unknown(""))]
      : gate.reasons.map { SafetyReasonCopy.calmCopy(for: $0) }
  }
}
