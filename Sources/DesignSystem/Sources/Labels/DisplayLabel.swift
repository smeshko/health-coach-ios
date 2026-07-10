import SwiftUI

/// The single presentation boundary (ARCHITECTURE §9, D19, principle #2): every domain enum maps to a
/// human label **here**, so a raw machine key never reaches a view. Conformance via `DisplayLabel` is
/// the only public display path — `DesignSystem` never surfaces an enum's `rawValue` /
/// `String(describing:)`.
public protocol DisplayLabel {
  var label: String { get }
}

/// An optional token-color cue (readiness band / HR zone / intensity) — paired with the label so color
/// is never the sole signal (PRD §9.4).
public protocol DisplayColored {
  var color: Color { get }
}

/// An optional SF Symbol icon cue (fill variants for active/emphasis).
public protocol DisplayIconed {
  var iconName: String { get }
}

/// A `DesignSystem`-owned mirror of the six PRD §12 error codes (DECISIONS #3). `ErrorCode` lives in
/// `WireModels`/`APIError`, which §4.4 forbids `DesignSystem` from importing — the feature
/// error-presenter maps an `APIError` onto this at the boundary.
public enum ErrorDisplay: Sendable, Hashable, CaseIterable {
  case unauthorized
  /// A freshly-typed connect token was rejected — distinct from `.unauthorized` (a *prior* session
  /// going invalid). Rendered in the Connect field error; the 401 reason banner keeps `.unauthorized`.
  case tokenRejected
  /// The Connect probe never got an answer (transport failure, timeout, unconfigured client) —
  /// reachability, not rejection. Distinct from `.tokenRejected` so a down server can't read as
  /// "your token is wrong".
  case serverUnreachable
  case validationError
  case notFound
  case briefGenerationFailed
  case upstreamTimeout
  case internalError
  case unknown
}

extension ErrorDisplay: DisplayLabel {
  public var label: String {
    switch self {
    case .unauthorized: "Session expired — reconnect to continue."
    case .tokenRejected: "That token doesn't look right. Check it and paste again."
    case .serverUnreachable: "Can't reach the server — check your connection and server address."
    case .validationError: "Something didn't look right — please try again."
    case .notFound: "We couldn't find that."
    case .briefGenerationFailed: "Couldn't build your brief — try again in a moment."
    case .upstreamTimeout: "The server took too long — try again."
    case .internalError: "Something went wrong on our end — try again."
    case .unknown: "Something went wrong — try again."
    }
  }
}

/// A graceful human label for an open enum's `.unknown(raw)` arm — `"sleep_below_7h"` /
/// `"sleepBelow7h"` → `"Sleep Below 7h"` — so a raw key never renders.
func gracefulLabel(forUnknownRaw raw: String) -> String {
  guard !raw.isEmpty else { return "Unknown" }
  // Split snake_case and camelCase into words, including a letter→digit boundary ("Below7h" →
  // "Below 7h") but not a digit→letter one (keep "7h" together).
  var spaced = ""
  for character in raw.replacingOccurrences(of: "_", with: " ") {
    if let last = spaced.last, last != " ", !last.isNumber, character.isUppercase || character.isNumber {
      spaced.append(" ")
    }
    spaced.append(character)
  }
  let titled = spaced
    .split(separator: " ")
    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
    .joined(separator: " ")
  return titled.isEmpty ? "Unknown" : titled
}
