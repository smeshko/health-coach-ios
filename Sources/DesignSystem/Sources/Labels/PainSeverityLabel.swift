import SwiftUI

/// Knee-pain severity bands derived from the 0–10 scale (DECISIONS #2):
/// `0 → None`, `1...3 → Mild`, `4...6 → Moderate`, `7...10 → Severe`. A pure, centralized, testable
/// mapping so the badge copy never lives in a view. The authoritative 0–10 clamp stays in
/// `CheckInComponent` — this maps whatever value it is given (out-of-range maps gracefully).
public enum PainSeverity: Sendable, CaseIterable, DisplayLabel {
  case none
  case mild
  case moderate
  case severe

  public init(value: Int) {
    switch value {
    case ..<1: self = .none
    case 1...3: self = .mild
    case 4...6: self = .moderate
    default: self = .severe
    }
  }

  public var label: String {
    switch self {
    case .none: "None"
    case .mild: "Mild"
    case .moderate: "Moderate"
    case .severe: "Severe"
    }
  }

  /// The "N · <severity>" badge text shown beside the knee-pain stepper (e.g. "2 · Mild").
  public static func badge(for value: Int) -> String {
    "\(value) · \(PainSeverity(value: value).label)"
  }
}
