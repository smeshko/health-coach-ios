import ComposableArchitecture
import DesignSystem
import HealthKitClient
import XCTest

@testable import OnboardingFeature

/// Exhaustive coverage for the `HealthKitPriming` state machine, the `PrimingRow` grouping vocabulary,
/// and the `DesignSystem` label boundary (Phase 7.3 TASK-001 — pure transitions only; the authorize +
/// degraded-probe effects are exercised in TASK-002). Host-runnable: no HealthKit, no simulator.
@MainActor
final class HealthKitPrimingTests: XCTestCase {
  // MARK: PrimingRow grouping (the degraded-inference seam)

  /// The union of every row's categories **equals** the full `HealthDataCategory` set — every category
  /// has exactly one home (disjoint + exhaustive), incl. `respiratoryRate` (folds into Heart rate) and
  /// `activity` (folds into Active & basal energy).
  func test_primingRows_categoriesAreDisjointAndCoverEveryCategory() {
    var seen = Set<HealthDataCategory>()
    for row in PrimingRow.allCases {
      XCTAssertFalse(row.categories.isEmpty, "\(row) maps to no category")
      XCTAssertTrue(seen.isDisjoint(with: row.categories), "\(row) double-maps a category")
      seen.formUnion(row.categories)
    }
    XCTAssertEqual(seen, Set(HealthDataCategory.allCases), "rows must cover every HealthDataCategory")
  }

  /// `runningForm` is the sole home for `runningDynamics` (so the row is mandatory, not conditional).
  func test_runningForm_isSoleHomeOfRunningDynamics() {
    let homes = PrimingRow.allCases.filter { $0.categories.contains(.runningDynamics) }
    XCTAssertEqual(homes, [.runningForm])
  }

  /// `primingGroups` collapses the 11 degraded rows into the 8 priming-screen groups.
  func test_primingGroups_areTheEightDesignGroups() {
    XCTAssertEqual(
      PrimingRow.primingGroups,
      [.heartRate, .sleep, .steps, .vo2Max, .runningForm, .workoutsEffort, .bodyWeight, .dietary]
    )
  }

  // MARK: DesignSystem label boundary (no raw machine key reaches a view)

  /// Every `HealthDataCategory` and every `PrimingRow` resolves to a non-empty human title via the
  /// `DesignSystem` boundary, never the raw case name.
  func test_labels_areNonEmpty_andNotRawCaseNames() {
    for category in HealthDataCategory.allCases {
      let label = category.signalLabel
      XCTAssertFalse(label.title.isEmpty, "\(category) has an empty signal label")
      XCTAssertNotEqual(label.title, category.rawValue, "\(category) renders its raw value")
      XCTAssertNotEqual(label.title, String(describing: category), "\(category) renders its raw case name")
      XCTAssertFalse(label.iconName.isEmpty, "\(category) has no icon")
    }
    for row in PrimingRow.allCases {
      XCTAssertFalse(row.rowLabel.title.isEmpty, "\(row) has an empty row label")
      XCTAssertNotEqual(row.rowLabel.title, String(describing: row), "\(row) renders its raw case name")
    }
    for group in PrimingRow.primingGroups {
      XCTAssertFalse(group.groupLabel.title.isEmpty, "\(group) has an empty group label")
      XCTAssertFalse(group.groupLabel.subtitle.isEmpty, "\(group) has an empty group subtitle")
    }
  }

  /// The priming-group head copy matches the design (and is distinct from the per-row label for the
  /// grouped heads — `heartRate` heads "Heart & recovery", not "Heart rate").
  func test_groupHeads_useGroupCopy_distinctFromRowCopy() {
    XCTAssertEqual(PrimingRow.heartRate.groupLabel.title, "Heart & recovery")
    XCTAssertEqual(PrimingRow.heartRate.rowLabel.title, "Heart rate")
    XCTAssertEqual(PrimingRow.steps.groupLabel.title, "Activity & energy")
    XCTAssertEqual(PrimingRow.steps.rowLabel.title, "Steps")
  }

  // MARK: Pure state transitions (no effects in TASK-001)

  func test_initialState_isPriming_andConnectTapped_entersAuthorizing() async {
    let store = TestStore(initialState: HealthKitPriming.State()) {
      HealthKitPriming()
    }
    XCTAssertEqual(store.state.phase, .priming)
    await store.send(.connectTapped) { $0.phase = .authorizing }
  }

  func test_continueTapped_fromDegraded_emitsFinished() async {
    let summary = HealthKitPriming.DegradedSummary(missing: [.sleep], bannerSignal: .sleep)
    let store = TestStore(initialState: HealthKitPriming.State(phase: .degraded(summary))) {
      HealthKitPriming()
    }
    await store.send(.continueTapped)
    await store.receive(\.delegate, .finished)
  }
}
