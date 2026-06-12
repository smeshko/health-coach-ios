import DomainModels

/// The single source of truth the parent `TodayFeature` switches on so **forced-REST** and **coach-easy**
/// are distinct rendered states (ARCHITECTURE §8 / §1 principle #6 / PRD §7.4.2 / the openapi spec header),
/// never one screen toggled by a flag.
///
/// Detection is the authoritative wire signal `safetyGate.triggered` (DECISIONS #2) — *not* "empty
/// alternatives" (a *consequence* of a trip, not its cause). A coach-chosen easy day is also gentle but
/// `triggered == false` with real `alternatives`.
public enum TodaySessionMode: Equatable {
  /// A tripped safety gate (`safetyGate.triggered == true`) — the dedicated calm forced-REST screen.
  ///
  /// **Type note (load-bearing):** `override` is the fully-expanded `brief.session` (a `SessionBlock`) —
  /// the rendered form of the gate's `overrideTo` card on a trip. It is **not** `gate.overrideTo`, which
  /// is a `Card?` (openapi card enum) that merely *names* the forced card. `SessionCard` takes a
  /// `SessionBlock`, never a `Card`.
  case forcedRest(gate: DomainModels.SafetyGate, override: DomainModels.SessionBlock)
  /// An untripped day (`triggered == false`) — the ordinary session path (coach-easy or otherwise),
  /// rendered by Phase 8.4's `SessionFeature`. This phase only routes to it.
  case normal(DomainModels.SessionBlock)

  /// The pure derivation from the already-loaded brief: `.forcedRest` iff the gate is tripped, else
  /// `.normal`. No client computation (principle #4) — it reads the server's `triggered` flag verbatim.
  public static func from(_ brief: DomainModels.DailyBrief) -> TodaySessionMode {
    brief.safetyGate.triggered
      ? .forcedRest(gate: brief.safetyGate, override: brief.session)
      : .normal(brief.session)
  }
}
