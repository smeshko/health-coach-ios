import DomainModels

/// The forced-REST screen's calm reason copy (PRD §7.4.2) — the **single** translation point from a typed
/// `SafetyReason` to its full calm sentence (DECISIONS #3, principle #2). Distinct from (and longer than)
/// the §12.3 `SafetyReason.label` chips ("Gut flare"): these are the screen's gentle, good-coaching
/// headline.
///
/// The sentences are **transcribed verbatim from the PRD §7.4.2 reason→copy table** — fixed UX chrome
/// about a *code-written* gate state (whose own `narrative` is code-written per §7.4.2), the same class as
/// the §12 label tables and §8.3 error copy. They are **not** authored coaching prose over the server
/// `narrative` (which stays verbatim via `NarrativeRenderer`), so principle #1 is not violated. `.unknown`
/// → a generic graceful line, so no raw machine key and no blank headline ever reach the screen.
enum SafetyReasonCopy {
  static func calmCopy(for reason: DomainModels.SafetyReason) -> String {
    switch reason {
    case .giFlare: "Your gut needs a break today."
    case .illness: "You flagged feeling unwell — recover first."
    case .kneePainHigh: "Knee pain is high — no running or jumping today."
    case .sleepBelow4h: "Very little sleep — today is for recovery."
    case .rhrSpike: "Your resting heart rate spiked — back off today."
    case .hrvCrash: "Your HRV dropped sharply — recover today."
    case .unknown: "Today is for recovery."
    }
  }
}
