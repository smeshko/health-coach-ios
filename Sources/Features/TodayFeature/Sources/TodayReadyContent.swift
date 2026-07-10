import ComposableArchitecture
import DesignSystem
import DomainModels
import SwiftUI

/// The `ready` content area: the cached-freshness label, then either the **exercise** arm — the
/// **readiness gauge** (Phase 8.3) above the **forced-REST vs normal-session** switch (`TodaySessionMode`,
/// Phase 8.3) — or the **nutrition** arm (Phase 8.5). The check-in is **not** here: it presents as a full
/// cover on top of this view (`TodayView`'s `ZStack`), so a loaded brief never shows the check-in inline
/// (the 2026-06-10 design — the check-in is its own screen). The Exercise|Nutrition `SegTabs` toggle is
/// wired through `selectedSection`/`sectionSelected`.
///
/// Extracted to its own file (the `CheckInSection` precedent) to keep `TodayView.swift` under the 400-line
/// lint cap after Phase 12.3's animation wiring — module-internal, not `private`.
struct TodayReadyContent: View {
  @Bindable var store: StoreOf<TodayFeature>
  let brief: DomainModels.DailyBrief
  let cachedLabel: String?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // The Exercise | Nutrition switcher (`Today · Exercise.png` / `Today · Nutrition.png`) — sits above
      // the brief content, only in `ready` (no brief → no sections). Selection lives in `selectedSection`;
      // taps route through `.sectionSelected` so the reducer owns the toggle (exhaustively testable).
      SegTabs(selection: Binding(
        get: { store.selectedSection == .nutrition ? .nutrition : .exercise },
        set: { store.send(.sectionSelected($0 == .nutrition ? .nutrition : .exercise)) }
      ))

      if let cachedLabel {
        Text(cachedLabel)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
      }

      switch store.selectedSection {
      case .exercise:
        // Each arm is a single spacing-matched `VStack` so the section swap crossfades as one unit (Phase
        // 12.3): the wrapping VStack keeps `spaceMd` between its children — identical layout to the former
        // direct-child arrangement, so static snapshots are unchanged — while giving the arm one identity
        // to attach `.transition(.opacity)` to.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          // The readiness gauge (Phase 8.3), scoped so its "why" toggle persists. The summary narrative
          // ("Good morning …") is parent-filtered and passed in.
          if let readinessStore = store.scope(state: \.readiness, action: \.readiness) {
            ReadinessComponentView(
              store: readinessStore,
              summary: brief.narrative.filter { $0.type == .summary }
            )
          }

          // Forced-REST vs the ordinary session are **distinct rendered states** (ARCHITECTURE §8 / §1
          // principle #6 / PRD §7.4.2), chosen by the authoritative `safetyGate.triggered` signal. The
          // switch is **exhaustive** (no `default:`), mirroring the `briefState` discipline.
          switch TodaySessionMode.from(brief) {
          case let .forcedRest(gate, override):
            // The dedicated calm forced-REST screen — read-only override session, no swap/skip/alternatives.
            // Chip rule: the override's `zoneTarget` drives (rest/mobility have none → no chip); zones nil
            // ⇒ silent degrade — mirroring the normal session card's resolution.
            SafetyRestView(
              gate: gate,
              overrideSession: override,
              zoneRange: TodaySessionMode.overrideZoneRange(override: override, zones: store.zones),
              narrative: brief.narrative.filter { $0.type == .session || $0.type == .caution }
            )
          case .normal:
            // The promoted `SessionFeature` (Phase 8.4) renders the displayed session through the
            // `SessionCard` with the inline SWAP-TO list + the warm skip affordance. The parent hydrates
            // `state.session` exactly on the untripped (`.normal`) path, so the scope is non-nil here.
            if let sessionStore = store.scope(state: \.session, action: \.session) {
              SessionFeatureView(store: sessionStore)
            }
          }
        }
        .transition(.opacity)
      case .nutrition:
        // MARK: - Phase 8.5 nutrition

        // The TODAY'S FUEL panel + COACH NOTE, then the yesterday recap / no-food empty state — co-equal
        // with the workout (PRD §7.4.4 / §6 principle 4). Both are render-only sub-components constructed
        // inline from the loaded brief (the `SafetyRestComponent` precedent), so they hold no parent state
        // and need no reducer scope.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          NutritionView(brief: brief)
          YesterdayIntakeView(intake: brief.intakeYesterday)
        }
        .transition(.opacity)
      }
    }
    // Crossfade the Exercise↔Nutrition content on the `selection` token so it swaps in lock-step with
    // 12.2's SegTabs capsule slide (Phase 12.3, TASK-002). View-scoped (DECISIONS D2); Reduce Motion →
    // `selection` resolves to `nil`, so the content snaps in step with the (also-snapping) capsule.
    .coachAnimation(.selection, value: store.selectedSection)
  }
}
