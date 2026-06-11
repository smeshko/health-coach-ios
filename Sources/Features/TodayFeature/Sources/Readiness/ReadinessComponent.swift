import ComposableArchitecture
import DesignSystem
import DomainModels

/// The readiness sub-component of `TodayFeature` (ARCHITECTURE §4.5, PRD §7.4.1) — the daily readiness
/// gauge + its tappable, itemized "why" breakdown. **Internal** to `TodayFeature` (D5 — readiness is
/// Today-only, never promoted); the parent scopes it from the loaded `DailyBrief`.
///
/// Readiness is **physiological-only** (PRD §7.4.1): `State` carries *only* the domain `Readiness`
/// (`score`/`band`/`penalties`) — the morning check-in is structurally unreachable here, so the
/// "ignores the check-in" guarantee can't be violated. The check-in feeds the **safety gate**
/// ([[SafetyRestComponent]]), never this score.
///
/// **Feature dependency rule (§3):** imports only `ComposableArchitecture` + `DomainModels` +
/// `DesignSystem` (the 5.1 `DisplayLabel` boundary for `PenaltyFactor.label`). No repository
/// `@Dependency`, no `WireModels`/GRDB/HealthKit. It builds **no** readiness numbers (principle #4) — it
/// surfaces the server `score`/`band`/`penalties` verbatim.
@Reducer
public struct ReadinessComponent {
  @ObservableState
  public struct State: Equatable {
    /// The server's readiness — the only thing this component sees. No check-in field (PRD §7.4.1).
    public var readiness: DomainModels.Readiness
    /// Whether the itemized "why" breakdown is expanded. Lives in the reducer (not opaque SwiftUI
    /// `@State`) so the toggle is exhaustively `TestStore`-assertable (DECISIONS #1).
    public var isWhyExpanded: Bool

    public init(readiness: DomainModels.Readiness, isWhyExpanded: Bool = false) {
      self.readiness = readiness
      self.isWhyExpanded = isWhyExpanded
    }

    /// The itemized "why" rows — one per server penalty, **in received order** (no filtering /
    /// reordering / thresholding — principle #4). Each `factor` is mapped through the 5.1
    /// `DisplayLabel` boundary (`PenaltyFactor.label`), so a raw machine key never reaches the view
    /// (an `.unknown(raw)` factor still yields a graceful label). `points` is the server's value —
    /// **positive** in the domain (`{factor, points}` with `points` the magnitude docked); the view
    /// renders the leading "−".
    public var penaltyRows: [PenaltyRow] {
      readiness.penalties.map { PenaltyRow(label: $0.factor.label, points: $0.points) }
    }
  }

  /// One row of the readiness "why" breakdown — a display label + the points docked (positive; the view
  /// renders the "−"). A structured `(label, points)` pair so the mapping is asserted per row, not by
  /// matching a rendered string. 1-level nested (the type-nesting lint rule).
  public struct PenaltyRow: Equatable {
    public var label: String
    public var points: Int

    public init(label: String, points: Int) {
      self.label = label
      self.points = points
    }
  }

  public enum Action {
    /// The "Why ›" affordance — toggles the inline breakdown open/closed.
    case whyTapped
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .whyTapped:
        state.isWhyExpanded.toggle()
        return .none
      }
    }
  }
}
