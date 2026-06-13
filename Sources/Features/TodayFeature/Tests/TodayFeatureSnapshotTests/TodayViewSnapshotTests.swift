// TodayView snapshots (ARCHITECTURE D16): the lifecycle chrome states — the redesigned **loading
// (`.syncing`)** and **generating** states (`2 ·`/`3 · Loading` mockups), **sync-failed**, and the
// redesigned **check-in screen** (`1 · Daily Check-in.png`, the `.checkInRequired` gate — no section
// toggle until a brief is available) — in light + dark on the single reference device, via the shared
// `CoachTestSupport` harness. The whole body is `#if canImport(UIKit)`-guarded so this target compiles
// to an empty module on the macOS host (so `swift test` stays green); it runs on the pinned iOS 26
// simulator via `make test-snapshots`.
//
// The shell header reads `@Dependency(\.date)`/`(\.calendar)` for the date subtitle, so each snapshot is
// wrapped in `withDependencies` to pin a fixed Europe/Sofia instant (deterministic references). The full
// `.ready` brief content (readiness gauge, session, nutrition) is still 8.2–8.4's; the check-in snapshot
// pins `checkInRepository.current` so the `.task` load is a no-op and the seeded card is captured.

#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import DomainModels
  import Foundation
  import SampleData
  import SnapshotTesting
  import Testing

  @testable import TodayFeature

  @MainActor
  struct TodayViewSnapshotTests {
    /// A fixed wall-clock instant in Europe/Sofia (Friday, June 5 2026) so the date subtitle is stable.
    private func fixedInstant() -> Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 5
      components.hour = 9
      return Calendar.europeSofia.date(from: components)!
    }

    /// 7:02 AM in Europe/Sofia (Friday, June 5 2026) — the check-in footer's "Last saved" stamp.
    private func savedAtInstant() -> Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 5
      components.hour = 7
      components.minute = 2
      return Calendar.europeSofia.date(from: components)!
    }

    private func view(_ state: BriefViewState) -> TodayView {
      TodayView(store: Store(initialState: TodayFeature.State(briefState: state)) { TodayFeature() })
    }

    @Test func test_syncing() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.syncing))
      }
    }

    @Test func test_generating() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.generating))
      }
    }

    @Test func test_syncFailed() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.syncFailed(.network)))
      }
    }

    /// The redesigned check-in screen (`1 · Daily Check-in.png`) — the `.checkInRequired` gate, now an
    /// opaque full **cover on top** of the (not-yet-loaded) brief, seeded to the mockup's "2 · Mild" knee
    /// pain and a 7:02 AM "Last saved" footer. `current` is pinned so the card's `.task` load is a no-op and
    /// the seeded state is what's captured.
    @Test func test_checkIn() {
      let state = TodayFeature.State(
        briefState: .checkInRequired,
        checkIn: CheckInComponent.State(kneePain: 2, lastSavedAt: savedAtInstant())
      )
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
        $0.checkInRepository.current = { _ in nil }
      } operation: {
        assertCoachSnapshot(of: TodayView(store: Store(initialState: state) { TodayFeature() }))
      }
    }

    /// A deterministic five-zone bpm map (matching the host helpers') so the ready session card renders.
    private func zones() -> DomainModels.Zones {
      DomainModels.Zones(
        z1: DomainModels.ZoneRange(low: 95, high: 114),
        z2: DomainModels.ZoneRange(low: 114, high: 133),
        z3: DomainModels.ZoneRange(low: 133, high: 152),
        z4: DomainModels.ZoneRange(low: 152, high: 171),
        z5: DomainModels.ZoneRange(low: 171, high: 190)
      )
    }

    /// The loaded `.ready` brief (the exercise arm) — the readiness gauge above the session card, with **no
    /// inline check-in**: the check-in is its own cover screen (above), so a loaded brief never shows it
    /// alongside the exercise/nutrition view (the 2026-06-10 design). The child sub-states are hydrated as
    /// the reducer does on `._briefResolved`.
    @Test func test_ready_exercise_noInlineCheckIn() {
      let brief = SampleData.dailyBriefGreen
      let map = zones()
      let state = TodayFeature.State(
        briefState: .ready(brief, .fresh),
        readiness: ReadinessComponent.State(readiness: brief.readiness),
        session: SessionFeature.State(
          session: brief.session,
          alternatives: brief.alternatives,
          skipOk: brief.skipOk,
          narrative: brief.narrative.filter { $0.type == .session },
          zones: map
        ),
        zones: map
      )
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: TodayView(store: Store(initialState: state) { TodayFeature() }))
      }
    }

    /// The `.ready` brief with `isBackgroundRefreshing == true` (Phase 12.1): the header shows the
    /// "Updating…" pill + spinner instead of the synced pill. `lastSyncedAt` is set so the difference is
    /// the pill swap, not its absence.
    @Test func test_ready_backgroundRefreshing_showsUpdatingPill() {
      let brief = SampleData.dailyBriefGreen
      let map = zones()
      let state = TodayFeature.State(
        briefState: .ready(brief, .fresh),
        readiness: ReadinessComponent.State(readiness: brief.readiness),
        session: SessionFeature.State(
          session: brief.session,
          alternatives: brief.alternatives,
          skipOk: brief.skipOk,
          narrative: brief.narrative.filter { $0.type == .session },
          zones: map
        ),
        zones: map,
        lastSyncedAt: fixedInstant(),
        isBackgroundRefreshing: true
      )
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: TodayView(store: Store(initialState: state) { TodayFeature() }))
      }
    }
  }
#endif
