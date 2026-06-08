import Foundation

/// Inline JSON string fixtures for the wire decode tests.
///
/// Inline, **not** `SampleData` — that target depends on `WireModels` and lands in Phase 2.3
/// (PLAN Decisions). When 2.3 consolidates the canonical fixtures, these tests can be re-pointed
/// at them. `date-time` fixtures use whole seconds + the Europe/Sofia `+03:00` (June) offset so a
/// decode → encode → decode round-trip is exact.
enum Fixtures {
  static let dailyBrief = """
  {
    "data": {
      "date": "2026-06-06",
      "readiness": {
        "score": 82,
        "band": "green",
        "penalties": [{ "factor": "low_hrv", "points": 8 }]
      },
      "safetyGate": { "triggered": false, "reasons": [] },
      "session": {
        "card": "easy_run",
        "intensity": "easy",
        "durationMinLow": 40,
        "durationMinHigh": 55,
        "flags": ["zone2"],
        "zoneTarget": "z2",
        "hrCapBpm": 150
      },
      "alternatives": [
        {
          "card": "active_recovery",
          "intensity": "recovery",
          "durationMinLow": 20,
          "durationMinHigh": 30,
          "flags": []
        }
      ],
      "skipOk": true,
      "macroFocus": {
        "dayType": "moderate",
        "caloriesKcal": 2600,
        "proteinG": 170,
        "carbsG": 300,
        "fatGLow": 60,
        "fatGHigh": 80,
        "hydrationLLow": 2.5,
        "hydrationLHigh": 3.5
      },
      "intakeYesterday": null,
      "generatedAt": "2026-06-06T07:30:00+03:00",
      "cached": false,
      "constitutionVersion": "v3"
    },
    "narrative": [
      { "type": "summary", "heading": "Good to go", "body": "Readiness is green." }
    ]
  }
  """

  static let weeklyPlan = """
  {
    "data": {
      "isoWeek": "2026-W24",
      "weekStart": "2026-06-08",
      "budgets": { "hardDays": 2, "strengthSessions": 2, "longRunKm": 18.0, "deload": false },
      "core": [
        {
          "card": "long_run",
          "tier": "core",
          "intensity": "easy",
          "isHardDay": false,
          "flags": ["zone2"],
          "suggestedDay": "sun",
          "durationMinLow": 80,
          "durationMinHigh": 100
        }
      ],
      "extras": [],
      "targets": {
        "totalRunKm": 45.0,
        "easyRunRatio": 0.8,
        "strengthSessions": 2,
        "hardDays": 2,
        "cadenceSpm": 178
      },
      "nutrition": {
        "proteinG": 170,
        "fatGLow": 60,
        "fatGHigh": 80,
        "hydrationLLow": 2.5,
        "hydrationLHigh": 3.5,
        "avgCaloriesKcal": 2600,
        "dayTypePattern": [
          { "suggestedDay": "mon", "dayType": "moderate", "caloriesKcal": 2600, "carbsG": 300 }
        ],
        "restDay": { "caloriesKcal": 2200, "carbsG": 220 },
        "lastWeek": { "avgCaloriesKcal": 2550, "proteinHitDays": 5 }
      },
      "constantsRecomputed": false,
      "generatedAt": "2026-06-06T07:30:00+03:00",
      "cached": false
    },
    "narrative": [
      { "type": "plan", "heading": "Week 24", "body": "Build week." }
    ]
  }
  """

  static let profileResponse = """
  {
    "athlete": { "age": 34, "sex": "male", "heightCm": 182, "goalWeightKg": 75.0 },
    "zones": {
      "z1": { "low": 100, "high": 130 },
      "z2": { "low": 131, "high": 145 },
      "z3": { "low": 146, "high": 160 },
      "z4": { "low": 161, "high": 175 },
      "z5": { "low": 176, "high": 190 }
    },
    "thresholds": {
      "maxHr": 190,
      "rhrBaseline": 48,
      "hrvBaselineMs": 65,
      "easyHrCap": 150,
      "cadenceCurrentSpm": 172,
      "cadenceTargetSpm": 180
    },
    "meta": { "constitutionVersion": "v3", "constantsRecomputedWeek": "2026-W22" }
  }
  """

  static let syncResponse = """
  {
    "recordsUpserted": 12,
    "recordsDuplicate": 3,
    "workoutsUpserted": 1,
    "activityDaysUpserted": 1,
    "checkinSaved": true,
    "strengthTestSaved": false,
    "serverTime": "2026-06-06T07:30:00+03:00"
  }
  """

  static let healthResponse = """
  { "status": "ok", "serverTime": "2026-06-06T07:30:00+03:00" }
  """

  static let errorResponse = """
  {
    "error": {
      "code": "validation_error",
      "message": "Invalid request",
      "detail": "date must be yyyy-MM-dd"
    }
  }
  """

  // MARK: - Edge-case fixtures (null-vs-absent, forced-REST)

  /// `IntakeSummary` with the optional macro totals **explicitly `null`** (`vsTarget` still present).
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

  /// A forced-REST `DailyBrief` — a tripped safety gate is a normal `200`, not an error envelope.
  static let dailyBriefForcedRest = """
  {
    "data": {
      "date": "2026-06-06",
      "readiness": { "score": 28, "band": "red", "penalties": [{ "factor": "illness", "points": 50 }] },
      "safetyGate": { "triggered": true, "reasons": ["illness", "knee_pain"], "overrideTo": "rest" },
      "session": {
        "card": "rest",
        "intensity": "recovery",
        "durationMinLow": 0,
        "durationMinHigh": 0,
        "flags": ["forced_rest"]
      },
      "alternatives": [],
      "skipOk": true,
      "macroFocus": {
        "dayType": "rest",
        "caloriesKcal": 2200,
        "proteinG": 160,
        "carbsG": 220,
        "fatGLow": 60,
        "fatGHigh": 80,
        "hydrationLLow": 2.0,
        "hydrationLHigh": 3.0
      },
      "generatedAt": "2026-06-06T07:30:00+03:00",
      "cached": false
    },
    "narrative": [
      { "type": "caution", "heading": "Rest today", "body": "Illness flagged." }
    ]
  }
  """
}
