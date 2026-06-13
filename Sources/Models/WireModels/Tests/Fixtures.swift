import Foundation

/// Inline JSON survivors for the wire decode tests that genuinely DIVERGE from the canonical
/// `SampleData` resources.
///
/// Phase 11.6 (TASK-003) re-pointed the canonical-shape fixtures (daily/weekly/profile/sync/rest)
/// at `SampleData.jsonData(for:)` — one truth. Only the shapes below have no SampleData peer and so
/// stay inline; each survivor is justified by a comment.
enum Fixtures {
  /// The error envelope — SampleData ships no error-response resource (it only carries 200 payloads).
  static let errorResponse = """
  {
    "error": {
      "code": "validation_error",
      "message": "Invalid request",
      "detail": "date must be yyyy-MM-dd"
    }
  }
  """

  /// `IntakeSummary` with the optional macro totals **explicitly `null`** (`vsTarget` still present).
  /// Divergent: SampleData's intakes always carry macro totals; this pins null-vs-absent parity.
  static let intakeNullMacros = """
  {
    "date": "2026-06-06",
    "caloriesKcal": null,
    "proteinG": null,
    "carbsG": null,
    "fatG": null,
    "fiberG": null,
    "waterL": null,
    "vsTarget": { "caloriesPct": 0.0, "proteinHit": false }
  }
  """

  /// The same `IntakeSummary` with the optional macro-total keys **absent** — must decode identically.
  static let intakeAbsentMacros = """
  {
    "date": "2026-06-06",
    "vsTarget": { "caloriesPct": 0.0, "proteinHit": false }
  }
  """
}
