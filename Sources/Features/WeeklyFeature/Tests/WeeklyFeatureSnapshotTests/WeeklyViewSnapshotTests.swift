// WeeklyView snapshots (ARCHITECTURE D16, the 2026-06-10 "This Week" design): the shell `ready` states —
// the **normal** week (`weekly_plan_normal`: "a menu, not a schedule" subtitle, the expanded plan card,
// the dot-row + legend), the **deload** week (`weekly_plan_deload`: "easy on purpose" + the recovery
// narrative + the moon icon), and a **collapsed** plan card — in light + dark on the single reference
// device, via the shared `CoachTestSupport` harness. The whole body is `#if canImport(UIKit)`-guarded so
// this target compiles to an empty module on the macOS host; it runs on the pinned iOS 26 simulator via
// `make test-snapshots`.
//
// The shell reads `@Dependency(\.calendar)`/`(\.date)` for the week-range subtitle, so each snapshot is
// wrapped in `withDependencies` to pin a fixed Europe/Sofia instant (deterministic references). `WeeklyView`
// self-triggers no load (the tab attaches `.task`, TASK-007), so the seeded `.ready` state is captured.
#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import DomainModels
  import Foundation
  import SampleData
  import SnapshotTesting
  import Testing

  @testable import WeeklyFeature

  @MainActor
  struct WeeklyViewSnapshotTests {
    /// A fixed wall-clock instant in Europe/Sofia (Wednesday, June 3 2026) so the week-range subtitle is
    /// stable across runs.
    private func fixedInstant() -> Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 3
      components.hour = 9
      return Calendar.europeSofia.date(from: components)!
    }

    private func readyState(
      _ scenario: SampleScenario,
      section: WeeklySection = .exercise,
      expanded: Bool = true,
      coreExpanded: Bool = true
    ) throws -> WeeklyFeature.State {
      let plan = try SampleData.weeklyPlan(scenario).domain
      return WeeklyFeature.State(
        // `zones` is supplied (9.1's shell fetches it) so the session rows resolve "Zone N · bpm" lines.
        weeklyState: .ready(plan, .fresh),
        zones: SampleData.sampleProfile.zones,
        rhythm: WeekRhythmComponent.rhythm(from: plan),
        selectedSection: section,
        isPlanCardExpanded: expanded,
        isCoreExpanded: coreExpanded,
        nutrition: WeeklyNutritionComponent.make(from: plan),
        adherence: AdherenceComponent.make(from: plan.nutrition)
      )
    }

    private func view(_ state: WeeklyFeature.State) -> WeeklyView {
      WeeklyView(store: Store(initialState: state) { WeeklyFeature() })
    }

    @Test func test_normalWeek() throws {
      let state = try readyState(.weeklyPlanNormal)
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(state))
      }
    }

    @Test func test_deloadWeek() throws {
      let state = try readyState(.weeklyPlanDeload)
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(state))
      }
    }

    @Test func test_planCardCollapsed() throws {
      let state = try readyState(.weeklyPlanNormal, expanded: false)
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(state))
      }
    }

    /// The "Do these — Core" group collapsed (header + count chip only), the Optional group + targets
    /// still expanded (Phase 9.2).
    @Test func test_coreGroupCollapsed() throws {
      let state = try readyState(.weeklyPlanNormal, coreExpanded: false)
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(state))
      }
    }

    /// The Nutrition segment (Phase 9.3): the carb-cycling card + the nutrition narrative, the "Steady
    /// all week" constants, and the present "Last week" adherence scorecard.
    @Test func test_nutritionWeek() throws {
      let state = try readyState(.weeklyPlanNormal, section: .nutrition)
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(state))
      }
    }
  }
#endif
