# Coach App — iOS App UX PRD

> A UX-focused product requirements document for the **iOS app**, derived from the backend
> (`docs/architecture/*`, the wire contract in `MODELS.md`, the domain rules in
> `HEALTH-CONSITTUTION.md`, and the E1–E12 epic roadmap).
>
> **Scope of this document:** what the user sees and does — screens, flows, states, content, error
> handling, and edge cases. It is written to be handed to a UX designer as the brief for screen
> design. It deliberately omits non-functional requirements (latency budgets, infra, cost) and
> product strategy. Where the backend constrains a design choice, that constraint is called out.
>
> **A note on the data model.** Every brief the backend returns is split into two halves — `data`
> (pure structured numbers/enums → **build the UI from this**) and `narrative` (ordered
> coach-authored prose → **render this for the user to read**). This split is the single most
> important thing for a designer to internalise: numbers and prose never mix. Wherever this doc says
> "show X," X is a structured field; wherever it says "render the coach's words," that is narrative.

---

## 0. How to read this document

| Section | What's in it |
|---|---|
| §1–3 | The product, the one user, and the coaching voice — the "why" and the tone. |
| §4 | The shared vocabulary (cards, zones, bands, day types). Read this before the feature specs. |
| §5–6 | First-run/permissions and the daily app-open loop — the spine of the app. |
| §7 | Feature-by-feature functional requirements (the bulk of the work). |
| §8 | Cross-cutting UX: loading/cache/empty/error states and the edge-case catalogue. |
| §9 | Content & copy rules (narrative rendering, medical caution, tone do/don'ts). |
| §10–12 | Out of scope, open product questions, and an enum→label reference appendix. |

**Build-status caveat (read once, then design the full product):** the backend ships in epics. As of
this writing, `POST /sync` and `POST /brief/weekly` are implemented; `POST /brief/daily` (the daily
brief — the app's hero screen) is fully *specified* and is the next epic in flight (E11). There is
no history/trends endpoint yet (see §7.6, §11). **Design the complete intended product**; this doc
flags where the backend is ahead of or behind the design so nothing is a surprise.

---

## 1. Product in one paragraph

A **personal, single-user** health-coaching app for one athlete. Each morning the app reads the
user's Apple Health data, asks three quick check-in questions, and returns a **daily brief**: a
readiness score, one tuned workout suggestion (with alternatives and explicit permission to skip),
the day's nutrition targets versus what they actually ate yesterday, and a short coach note. Once a
week it returns a **weekly plan**: a small menu of "core" and "optional" sessions, the week's
training and nutrition targets, and the coach's rationale. The coach **adapts every day** to how
recovered the user is, and it **never overrides safety** — if the user is sick, injured, or
under-recovered, the app forces rest. It is a coach, not a logbook: the user does almost no data
entry.

## 2. The user (the only persona)

One person. There is no sign-up, no accounts, no social, no multi-user anything. Design for depth,
not breadth.

| Attribute | Value |
|---|---|
| **Who** | 34-year-old male. Runner + boxer, trains outdoors and at a park (calisthenics on bars). **No gym.** |
| **Goals (strict priority order)** | 1) **Body recomposition** — lose fat + gain muscle slowly, via a *modest* deficit + high protein ("protect muscle, sleep, and gut"). 2) **Run better** — build aerobic base, progress the long run toward **half-marathon** distance (no fixed race date). 3) **Upper-body muscle** via calisthenics. |
| **Capacity** | 4–5 sessions/week. Pattern: **2–3 "core" sessions + 1–2 optional "extras."** Not a fixed day-by-day calendar — a flexible pool. |
| **Body** | ~81 kg today (live from a connected scale via HealthKit), goal weight in profile, VO₂max ~42. **Sleep ~5.7 h/night — the #1 recovery limiter** the app actively nudges. ~10k steps/day. |
| **The three problems the app exists to fix** | (1) *No true-easy running* — even slow runs sit too hard → the app enforces an easy-HR cap. (2) *Low cadence / overstriding* that punishes knees + flat feet → a live cadence cue that ramps over time. (3) *Unmanaged intensity* — boxing is a hidden hard day → the app budgets hard days. |
| **Medical context** | Several managed conditions shape coaching **advice** (not a medical-device layer). See §9.2 — they surface as caution/nutrition coach notes, never as diagnoses. |

## 3. Design principles & the coaching voice

The voice is **auto-regulating, permission-giving, and reassuring — never a drill sergeant.** These
principles should be visible in layout priority, color, and copy.

1. **Recovery first, ego last.** Readiness and safety gate the day before any workout is shown.
   "Easy" should *feel* easy — the easy-pace cap "will feel humiliatingly slow at first; it is the
   point." Run/walk is explicitly fine. The UI should make resting feel like a smart choice, not a
   failure.
2. **The coach adapts; it doesn't scold.** An off day **downgrades** the plan (hard → easy, boxing →
   technique-only); it doesn't cancel it. There is an explicit **"skip is OK today"** signal — surface
   it as permission, warmly.
3. **Numbers are computed; prose is the coach.** Every number is trustworthy and deterministic. Show
   numbers plainly and let the **narrative** carry warmth, reasoning, and nuance.
4. **Nutrition is co-equal with training**, not an afterthought — it's "a first-class half" of every
   brief. Give it equal real estate.
5. **Medical caution outweighs optimization.** When advice conflicts, the safe choice wins. Caution
   copy is calm and non-alarming; the app **flags, never diagnoses**.
6. **Flexible, not rigid.** A weekly plan is a *menu with budgets*, not a locked calendar. Days are
   "suggested," and the daily brief may reshuffle. Avoid calendar metaphors that imply rigidity.

---

## 4. Shared vocabulary (read before §7)

The whole UI is built from a small, fixed vocabulary. A designer should treat each of these as a
first-class visual component with its own iconography and color.

### 4.1 Workout "cards" (the session types)

Every workout — planned or suggested — is exactly one of **20 cards**. The app never invents a
workout; it renders a card. Group them visually by family:

| Family | Cards | Visual cue |
|---|---|---|
| **Running** | `easy_run`, `long_run`, `progression_run`, `threshold`, `vo2`, `strides`, `active_recovery` | running iconography; intensity color |
| **Cardio** | `hiit`, `jump_rope`, `steady_cardio` | conditioning |
| **Strength** (calisthenics) | `strength_push`, `strength_pull`, `strength_lower`, `strength_full` | bars / bodyweight |
| **Boxing** | `boxing`, `boxing_technique` | gloves |
| **Mobility / prehab / rest** | `foot_prehab`, `glute_prehab`, `mobility`, `rest` | recovery |

Each card the app receives is **fully expanded** by the backend with: an **intensity**
(`easy`/`quality`/`recovery`), a **target HR zone** (z1–z5 or none), a **duration range** (e.g.
"30–40 min"), an optional **HR cap** (e.g. "≤146 bpm"), an optional **cadence cue** (e.g. "170 spm"),
and a set of **flags** (badges — see §4.4). The designer's job is to present this consistently across
the daily session, alternatives, and weekly sessions. See the label table in §12.1.

### 4.2 HR zones

Five zones, each a heart-rate range derived from the user's profile. Show as a small zone chip
(z1…z5) with its range, color-coded cool→hot. Example ranges (dynamic, from profile): z1 110–143,
z2 143–172, z3 172–191, z4 191–202, z5 202–220 bpm. **Z2 is "home base"** (~80% of running);
Z3 is "junk" to minimise; Z4/Z5 are the hard end.

### 4.3 Readiness bands & day types

- **Readiness band** (daily): `green` (≥75, "ready"), `amber` (50–74, "compromised — reduce"),
  `red` (<50, "don't push"). The hero gauge of the daily brief. Color = the universal traffic-light
  semantics the whole app leans on.
- **Day type** (nutrition): `hard` (carb-load, ~maintenance calories), `moderate` (mid carbs),
  `rest` (lowest carbs, biggest deficit). This is the one nutrition lever — it drives the day's
  carb/calorie target. Protein and fat hold roughly constant; **carbs and calories move with day
  type**. Note: a session's training-hardness and its fuel-demand are *different* — a long run is
  spacing-easy but fuel-`hard`. Don't conflate them in the UI.

### 4.4 Flags (session badges)

Cards carry machine flags that the app should translate into small, meaningful badges or footnotes.
The high-value ones for UX (full list in §12.2): `impact` (high ground impact; knee-gated),
`needs_green_knee` (only when the knee is healthy), `low_impact`/`prefer_low_impact` (knee-friendly
substitute), `append_to_easy` (a strides add-on, not a standalone), `effort_based` (run by feel, not
a hard HR ceiling — the long run), `auto_reg_downgrade` (this *is* the reduced version of a harder
session), `big_recovery_cost` (costs a lot of recovery — e.g. boxing), `prehab:foot`/`prehab:glute`
(tiny 5–10 min add-ons). These explain *why* a session looks the way it does and should be surfaced
as quiet, tappable context rather than jargon.

### 4.5 Narrative sections (the coach's prose)

All human-readable coaching text arrives as an ordered list of sections, each with a `type`, a
`heading`, and a `body` (markdown/plain). The `type` tells the app where to place and how to style
each section:

| `type` | Where it belongs | Styling hint |
|---|---|---|
| `summary` | top of the daily brief — the TL;DR for the day | prominent, the "lead" |
| `session` | next to / under the workout card | instructional |
| `nutrition` | in the nutrition area | distinct (food/medical-aware) |
| `caution` | a warning/medical note | calm, set-apart, non-alarming |
| `plan` | top of the weekly plan — the week's rationale | the weekly "lead" |

The app must render sections **in the order received** and may style by `type`. It must **not**
generate its own coaching prose — all words come from here.

### 4.6 Time & periods

All "today" / "this week" boundaries are computed server-side in **Europe/Sofia** time (DST-aware).
The app should display dates/weeks in that frame for consistency. The **daily brief is stable for the
whole day** (it's computed off the morning's data), so re-opening the app shows the same brief — design
for a "today's brief" that doesn't churn. Weeks are ISO weeks (`YYYY-Www`, e.g. `2026-W23`); the week
starts Monday.

---

## 5. Onboarding & permissions (first run)

There is **no account creation and no profile-setup wizard** — the user's constants (age, zones,
baselines, nutrition factors) are provisioned by the operator into the backend before first run, and
~90 days of history are pre-seeded so the very first brief is already meaningful. The app's first-run
job is therefore narrow:

**FR-ONB-1 — API connection.** The app must hold a single long-lived **bearer token** to reach the
backend. The designer should provide a minimal "connect" state (enter/paste token, or it's
provisioned out-of-band). A failed/expired token surfaces everywhere as a 401 → see §8.4. There is no
"forgot password" / account-recovery flow — re-entering the token is the only remedy.

**FR-ONB-2 — HealthKit authorization.** The app must request **read** access to a broad set of Apple
Health types: heart rate, HRV, resting HR, sleep, steps, active/basal energy, METs/effort, VO₂max,
**body weight**, running dynamics (speed/power/cadence/stride/ground-contact/vertical-oscillation),
workouts + their **effort score (RPE)**, and **dietary intake** (energy, protein, carbs, fat, fiber,
sodium, water). Design:
- A clear permission-priming screen explaining *why* each category matters (it's a coaching app,
  not surveillance) — Apple's HealthKit sheet is unskippable and ugly, so prime it well.
- A **graceful degraded state** when the user grants only some categories. The brief still works with
  partial data, but readiness/nutrition fidelity drops. The app should be able to tell the user
  "we're missing sleep data — readiness may be off."
- **Dietary data is read, not entered.** Food is logged in a third-party app (e.g. MyFitnessPal) that
  writes to HealthKit; this app only reads `dietary_*` records. There is **no in-app food logging**.
  Onboarding should explain this so the user connects their food app to Health.

**FR-ONB-3 — No body-weight entry, no workout entry.** Weight comes from HealthKit `body_mass`;
workouts come from HealthKit. The app must **not** offer manual entry for either. The only things the
user types are the daily check-in (§7.2) and the weekly strength test (§7.3).

---

## 6. The core loop — the "app-open sequence"

The backend has **no scheduler and sends no push notifications** (see §11). Everything is driven by
the app on open. The canonical morning sequence:

```
1.  User opens the app (ideally in the morning, after waking).
2.  User fills the daily check-in  → GI symptoms? · illness? · knee pain 0–10
3.  App POSTs /sync                 → pushes new HealthKit data + the check-in [+ weekly test]
4.  App POSTs /brief/daily          → today's tuned session, generated off the just-synced data
5.  If it's a new ISO week → app POSTs /brief/weekly  → this week's plan
```

**Design implications:**
- **Sync must precede the brief.** Readiness and the safety gate read the *just-synced* morning data.
  The UI should sequence "syncing your data…" before "building today's brief…" so a single
  pull-to-refresh or app-open runs both in order.
- The brief is **get-or-generate**: the first request of the day runs the AI (expect a **3–8 s
  spinner**); later requests that day return instantly from cache. The app can't know in advance
  whether it's a cache hit, so **always show a generating state and resolve fast on hits** (§8.2).
- Because there are no notifications, if the product wants a "good morning, check in" nudge it must be
  an **app-local notification** the iOS app schedules itself — there is no server support for it. Flag
  to product (§11) whether a local reminder is in v1.
- The **weekly** brief is generated lazily on the first open of a new week (often Monday morning), and
  may take an extra few seconds because it can also recompute the user's constants. Design a "new week
  — here's your plan" moment.

---

## 7. Feature requirements

Each feature below lists: **purpose**, the **data it consumes** (the structured fields), the
**components/states**, **edge cases**, and **copy/notes**. Numbers in examples are illustrative —
treat everything as dynamic.

---

### 7.1 HealthKit Sync (mostly invisible plumbing)

**Purpose.** Push new Health data + the check-in to the backend so the brief is built on fresh data.
Largely a background concern, but it has visible states.

**Mechanics the designer should respect:**
- The app sends **deltas** (only what's new since last sync), not the whole history.
- Sync is **idempotent** — re-sending the same data is safe; the response splits
  `recordsUpserted` vs `recordsDuplicate`. The app should treat sync as freely retryable.
- Sync returns counts + a `serverTime`. There is no error if there's simply nothing new to send.

**Visible states:**
- **Syncing** — a lightweight indicator ("Syncing health data…"), part of the app-open sequence.
- **Synced** — quiet confirmation; optionally a "last synced HH:MM" line in settings.
- **Sync failed** — network/auth error (§8.4). Sync failure should block the brief with a clear
  "couldn't sync — check connection" state and a retry, because a brief built on stale data is wrong.

**Edge cases:**
- **First ever sync** backfills available data including historical workout effort (RPE). It may be
  larger/slower than a normal delta — show a one-time "setting things up" state.
- **No new data** (e.g. user opens twice in a morning) → succeeds with zero upserts; don't treat as
  an error.
- **Partial HealthKit permissions** → some record types simply won't be present; not an error.

---

### 7.2 Daily Check-in (the only daily input)

**Purpose.** Capture the three **objective** signals the safety gate needs. "A few taps." This is the
gate to the day's brief and must feel fast and frictionless.

**Inputs (exactly three — nothing else):**

| Field | Control | Notes |
|---|---|---|
| `giSymptoms` | yes/no toggle | "Any gut-flare signs today?" — blood, >4 loose stools, urgency, or abdominal pain. A single yes/no. |
| `illness` | yes/no toggle | "Feeling ill / feverish?" |
| `kneePain` | 0–10 stepper/slider | **0 = none.** A value **>3** blocks running/jumping (impact gate). |

**Hard constraints / validation:**
- `kneePain` must be an integer **0–10**. The UI control should make out-of-range impossible; if the
  backend ever rejects it, it's a 422 (§8.3).
- **No subjective fields** — no mood, energy, soreness, or motivation. Readiness is objective-only by
  design. Do not add "how do you feel" sliders; they're deliberately excluded.
- **No body weight here** — weight is HealthKit.

**Behavior:**
- The check-in is **upsertable by date** — the user can submit, then change an answer and resubmit the
  same day; the latest wins. Design for "edit today's check-in."
- It should be the **first thing** in the morning flow (it feeds sync → brief). But the app should
  also allow getting a brief if the user skips the check-in (the gate just treats flags as
  absent/false) — don't hard-block, but encourage completion.

**Copy/notes.** Keep it warm and quick — three taps, not a medical intake form. The GI question is
sensitive; phrase plainly and without alarm.

---

### 7.3 Weekly Strength Test (the only weekly input)

**Purpose.** Track the upper-body muscle KPI. **Two numbers, once a week.**

**Inputs:**

| Field | Control | Notes |
|---|---|---|
| `maxPushups` | number | max reps in one set |
| `maxPullups` | number | max reps in one set |

**Behavior:**
- Sent only on test days; the **server derives the ISO week** — the app just sends the two numbers
  with today's date.
- These are **trend-smoothed KPIs** — the value of this feature is the *trend over time*, so the test
  should roll into a progress view (see §7.6).
- Cadence: roughly weekly. Because there's no scheduler, the **app must prompt** for the test itself
  (e.g. "It's been a week since your last strength test — log it?"). The backend just keys by ISO
  week and upserts, so re-testing in the same week overwrites.

**Edge cases.** A user may skip a week — that's fine; the trend simply has a gap. A user may retest —
the latest in the week wins.

---

### 7.4 Daily Brief — "Today" (the hero screen)

**Purpose.** The thing the user opens the app for: *what should I do today, and how should I eat?* — a
single screen built from the daily brief response. This is the app's centre of gravity.

The response has two halves: structured `data` (build the UI) and `narrative` (render the coach's
words). Below, each sub-component maps to fields in `data`, interleaved with the relevant narrative
section.

#### 7.4.1 Readiness (the top gauge)

**Data:** `readiness.score` (0–100), `readiness.band` (`green`/`amber`/`red`),
`readiness.penalties[]` (each `{factor, points}`, points negative).

**UX:** a prominent **readiness gauge/ring** colored by band, with the score. Tapping reveals the
**itemised "why"** — each penalty as a plain-language line with its point cost:

| `factor` | Plain-language line | Example |
|---|---|---|
| `sleep_below_7h` | "Short sleep" | −10 |
| `sleep_below_5h` | "Very short sleep" | (stacks) |
| `hrv_below_baseline` | "HRV below your baseline" | −15 |
| `rhr_above_baseline` | "Resting HR elevated" | — |
| `yesterday_hard_day` | "Hard session yesterday" | −15 |

Readiness is **purely physiological** (sleep, HRV, RHR, yesterday's load) — it does **not** read the
check-in. The breakdown is for transparency and for nudging better sleep (the #1 lever). Pair the
gauge with the `summary` narrative section as the day's lead.

#### 7.4.2 Safety gate & the forced-REST state (critical, distinct state)

**Data:** `safetyGate.triggered` (bool), `safetyGate.reasons[]` (machine keys),
`safetyGate.overrideTo` (the forced card, or null).

**Two fundamentally different "rest" cases the design must distinguish:**

1. **Forced REST (safety gate tripped).** When `triggered = true`, the AI was **skipped entirely** —
   the session is the deterministic `overrideTo` card (`rest` / `active_recovery` / `mobility`),
   `alternatives` is empty, and the narrative is **code-written** but still warm. This is **a normal
   200 response, not an error.** Design a distinct, calm "Today is a rest/recovery day" screen that
   names the reason gently. Reason keys → copy:

   | reason | Copy (calm, non-alarming) |
   |---|---|
   | `gi_flare` | "Your gut needs a break today." (from the GI check-in) |
   | `illness` | "You flagged feeling unwell — recover first." |
   | `knee_pain_high` | "Knee pain is high — no running or jumping today." |
   | `sleep_below_4h` | "Very little sleep — today is for recovery." |
   | `rhr_spike` | "Your resting heart rate spiked — back off today." |
   | `hrv_crash` | "Your HRV dropped sharply — recover today." |

   This state should feel like good coaching, not a punishment. Offer the override session (e.g. a
   gentle walk/mobility) as the positive action.

2. **Coach-recommended easy/rest (gate NOT tripped).** A normal day where the AI simply *chose* an
   easy or recovery session (e.g. amber readiness). Here `safetyGate.triggered = false`, there's a
   normal `session` + `alternatives`, and `skipOk` may be true. Present this as a regular (if gentle)
   workout, **not** the forced-REST screen.

#### 7.4.3 The session card (today's workout)

**Data:** `session` (a fully-expanded SessionBlock): `card`, `intensity`, `zoneTarget`,
`durationMinLow`/`durationMinHigh`, `hrCapBpm`, `cadenceSpm`, `flags`. Plus `alternatives[]`
(up to 2 same-shaped blocks) and `skipOk` (bool).

**UX — the primary action of the day:**
- A big **session card**: the card's human name (§12.1), the **duration range** ("30–40 min"), the
  **target zone** chip, and where present the **HR cap** ("keep HR ≤146") and **cadence cue**
  ("aim ~170 spm" — a candidate for a live metronome during the run). Intensity sets the accent color.
- **Flags as quiet badges/footnotes** (§4.4): e.g. an `impact` knee note, `needs_green_knee`, or a
  `prehab:foot` add-on. `append_to_easy` items (strides) should attach visually to the run, not stand
  alone.
- **Alternatives** (≤2): a swappable secondary option ("Prefer something lower-impact? Try…"). These
  are real, validated substitutes, not throwaways.
- **`skipOk`**: when true, surface an explicit, warm **"It's fine to skip today"** affordance — this is
  a core philosophy moment (permission to rest), not a dismiss button.
- Pair with the `session` narrative section, which carries the human "how to run it" instructions
  (e.g. "walk the hills, finish with 6–8 strides").

**Note on the long run:** `long_run` is `effort_based` (run by feel, late HR drift is fine) — its UI
should de-emphasise a hard HR ceiling and lean on the cadence cue + duration.

#### 7.4.4 Today's nutrition target (MacroFocus)

**Data:** `macroFocus`: `dayType`, `caloriesKcal`, `proteinG`, `carbsG`, `fatGLow`/`fatGHigh`,
`hydrationLLow`/`hydrationLHigh`.

**UX:** a nutrition panel with **equal weight to the workout**. Show the **day type** prominently
(hard/moderate/rest → "carb-load / standard / lower-carb") because it's the day's one nutrition
story, then the targets: calories, **protein (the constant — hit this every day)**, carbs (the lever
that moves with day type), a fat **range**, and a hydration **range**. Ranges are real — show "65–80 g
fat," not a single number. Pair with the `nutrition` narrative section, which carries the
medical-aware food guidance (lactose-safe protein, fat spread across meals, citrate/lemon water — see
§9.2).

#### 7.4.5 Yesterday's intake vs target

**Data:** `intakeYesterday` (nullable IntakeSummary): logged `caloriesKcal`, `proteinG`, `carbsG`,
`fatG`, `fiberG`, `waterL`, and `vsTarget` (`caloriesPct` = consumed÷target, `proteinHit` = met the
protein floor).

**UX:** a small "yesterday" recap that closes the loop — calories vs target as a percentage, a clear
**"protein: hit / missed"** marker (protein is the priority), and water/fiber. This is the only place
the app reflects *actual* eating back to the user (since food is logged elsewhere).

**Edge case — nothing logged.** `intakeYesterday` (and any sub-field) can be **null** if the user
logged no food. Design an **empty "no food logged yesterday"** state — a gentle nudge to connect/keep
logging in their food app, **not** an error and not zeros.

#### 7.4.6 Metadata (quiet)

`generatedAt`, `cached` (served-from-cache vs fresh), `constitutionVersion` (which rules snapshot).
Mostly invisible; `cached`/`generatedAt` can power a subtle "as of HH:MM" + a manual **Refresh**
(triggers `?refresh=true`, regenerating the brief — see §8.2). `constitutionVersion` is optional
debug metadata; not user-facing in normal use.

---

### 7.5 Weekly Plan — "This Week"

**Purpose.** The week's training + nutrition shape and the coach's rationale. A menu with budgets, not
a locked calendar. Opened on the first day of a new week (and viewable anytime that week).

#### 7.5.1 Budgets (the week's skeleton)

**Data:** `budgets`: `hardDays` (2, or 3 only when well-recovered), `strengthSessions` (protected at
2 — the muscle goal), `longRunKm` (nullable; capped at ≤10%/wk ramp), `deload` (bool).

**UX:** a compact "this week at a glance" header — *N hard days · 2 strength · long run ~11 km*. When
`deload = true`, badge the week clearly as a **lighter recovery week** and explain it warmly (planned
every ~4th week, or auto-triggered by under-recovery).

#### 7.5.2 Core & extra sessions

**Data:** `core[]` (2–3 PlannedSessions) and `extras[]` (1–2). Each PlannedSession: `card`, `tier`
(`core`/`extra`), `intensity`, `isHardDay`, `suggestedDay` (a hint, nullable), `zoneTarget`,
`durationMinLow`/`High`, `flags`.

**UX:** two clearly-separated groups — **Core (do these)** and **Extras (optional)**. Each is a
session card like §7.4.3 but with a **suggested day** chip. Crucially, communicate that
`suggestedDay` is a **hint, not a fixed appointment** — the daily brief may shuffle it. Mark
**hard days** (`isHardDay`) distinctly so the user can see the week's intensity rhythm (hard days are
budgeted and spaced — never back-to-back). Pair with `plan` and per-session `session` narrative
sections.

#### 7.5.3 Weekly targets (the numbers to hit)

**Data:** `targets`: `totalRunKm`, `easyRunRatio` (~0.8 — the polarized-training share),
`strengthSessions`, `hardDays`, `cadenceSpm` (this month's cue; ramps +5 every 2–3 weeks).

**UX:** a small targets strip. The **cadence cue** is a recurring, slowly-progressing number worth
surfacing consistently week to week (and live during runs). The `easyRunRatio` is the "80% easy"
philosophy made measurable — a candidate for a simple "easy vs hard" split visual.

#### 7.5.4 Weekly nutrition (the co-equal half)

**Data:** `nutrition` (WeeklyNutrition): constant `proteinG`, `fatGLow`/`High`, `hydrationLLow`/`High`,
`avgCaloriesKcal`, a **`dayTypePattern[]`** (one entry per planned session:
`{suggestedDay, dayType, caloriesKcal, carbsG}`), and **`lastWeek`** adherence (nullable:
`avgCaloriesKcal`, `avgProteinG`, `proteinHitDays`, `daysOverTarget`, `daysUnderTarget`).

**UX:**
- **Carb-cycling pattern** — visualize the week's day types as a row of days, each tagged
  hard/moderate/rest with its carb/calorie target, so the user *sees* "carbs ride up around the hard
  days, down on rest days." This is the headline nutrition story of the week.
- **Constants** — protein, fat range, hydration shown as steady targets.
- **Last week's adherence** — a small scorecard: avg calories vs target, avg protein, **protein-hit
  days (e.g. 4/7)**, days over/under. This is the only retrospective in the weekly brief; make it
  encouraging, not judgmental. **Nullable** → "not enough data last week" empty state.
- Pair with the `nutrition` narrative section.

#### 7.5.5 Recompute notice (quiet)

`constantsRecomputed` (bool) flags that the app's underlying constants were refreshed this week (a
monthly event). Optional, low-key: "Your zones/baselines were updated this week."

---

### 7.6 Trends & History — ⚠️ scope gap, design intent only

**Purpose.** Show progress over time — the payoff of consistency. The domain explicitly cares about
several **trends**:

| Trend | Source field(s) | The story |
|---|---|---|
| **Easy pace at the HR cap** | derived from runs over time | "getting faster at the same heart rate" — the *headline running metric*, not weekly mileage. |
| **Strength test** | `maxPushups` / `maxPullups` | upper-body muscle progress (trend-smoothed). |
| **Cadence ramp** | `targets.cadenceSpm` | climbing +5 every 2–3 weeks toward target. |
| **Long-run progression** | `budgets.longRunKm` | creeping up ≤10%/wk toward half-marathon. |
| **Readiness history** | daily `readiness.score` | recovery trend; correlate with sleep. |
| **Nutrition adherence** | `nutrition.lastWeek`, daily `intakeYesterday.vsTarget` | protein-hit streaks, deficit consistency. |
| **Weight trend** | HealthKit `body_mass` | slow recomposition. |

**⚠️ Backend gap the designer/product must resolve:** the backend currently exposes **only** the three
endpoints (`/sync`, `/brief/daily`, `/brief/weekly`) and has **no history/trends endpoint.** Trend
screens in v1 would have to be built from **data the app accumulates locally** from each day's/week's
brief responses (and from HealthKit directly for weight/pace), **or** require a new backend endpoint
that the current roadmap (E1–E12) does not include. **Flag this as an explicit product decision**
(§11). Design the trend views as intended, but mark them dependent on this decision.

---

### 7.7 Settings & connection

A small settings area for: the **API token / connection** state (§FR-ONB-1), **HealthKit permission**
status (with a path back to the iOS Health settings if categories are missing), **last sync** time,
and read-only display of profile constants if desired (age, zones, baselines — informational, not
editable in-app; constants are operator-managed). No notification settings beyond any app-local
reminder toggle the product chooses to add (§11). No account/logout (single user).

---

## 8. Cross-cutting UX: states, caching, errors, edge cases

### 8.1 The universal state model

Every brief screen moves through: **Idle → Syncing → Generating → Ready (fresh | cached) →
{Forced-REST | Error | Empty}**. Design these as a coherent set, not per-screen one-offs.

### 8.2 Loading, caching & refresh

- A brief is **get-or-generate**. First request of a day/week → AI runs → **3–8 s** spinner (hard
  cap ~60 s). Subsequent requests that period → instant from cache.
- The app **cannot know in advance** if it's a cache hit. **Always show a generating state on
  request**; it resolves instantly on hits and after a few seconds on misses. The response's `cached`
  flag tells you which happened (use it for an "as of HH:MM" label, not for pre-deciding the spinner).
- **Refresh.** Provide a manual "regenerate" affordance that calls `?refresh=true` — it discards the
  cached brief and runs the AI again (always returns fresh). Useful if the user synced new data after
  the morning brief, or just wants a re-roll. Make clear it costs a few seconds.
- **Stability.** The daily brief is intentionally stable for the day — re-opening shows the same
  brief. Don't auto-regenerate on every open; only sync + serve cache.

### 8.3 The error envelope

Every non-2xx response is one shape: `{ "error": { "code", "message", "detail" } }`. `code` is a
fixed set; `message` is a safe human summary; `detail` is usually null (populated only for validation
errors). Map each to a UX behavior:

| HTTP | `code` | What happened | UX behavior |
|---|---|---|---|
| **401** | `unauthorized` | Missing/invalid token | Route to the connect/re-auth state (§8.4). **Do not** silently retry. |
| **422** | `validation_error` | App sent a malformed payload (bad enum/date/range) | A *developer*-facing bug, not user-facing — the app's controls should prevent it. If it happens, show a generic "something went wrong, try again" and log it. `detail` has the field errors for debugging. |
| **404** | `not_found` | Resource missing | Generic not-found; rare in this single-user app. |
| **502** | `brief_generation_failed` | AI failed validation after retries, or returned bad structure | **Transient & retryable.** Nothing was cached. Show a friendly "couldn't build your brief — try again" with a Retry. |
| **504** | `upstream_timeout` | AI timed out | Same as 502 — friendly, retryable, with Retry. Optionally "the coach is taking long — retry." |
| **500** | `internal_error` | Unexpected server/data error | Often means **insufficient data** on a first-ever brief (sync first) — see §8.5. Show "we couldn't generate this yet — make sure your health data has synced," with Retry. Don't hammer-retry. |

**Important:** there is **no synthetic fallback brief.** A failure is always a real error envelope —
the app never receives a fake/placeholder workout. The only "rest" the app shows is the *legitimate*
safety-gate REST (a 200, §7.4.2) or a coach-chosen easy day — never an error masquerading as a
session.

### 8.4 Auth failure (401)

A missing or wrong token returns **401 `unauthorized`** with no distinction between "missing" and
"wrong." There is no token-refresh protocol and no 403 path. The app's only remedy is to re-establish
the token. UX: a clear "connection lost / token invalid — reconnect" state, **not** a retry loop.
Because the token is long-lived, a sudden 401 usually means a config/rotation issue, not normal
expiry.

### 8.5 Empty / cold-start / insufficient-data states

- **Before any sync** / on the very first brief, the backend may lack enough data to compute a brief
  and can return **500 `internal_error`** (there is no dedicated "no data yet" code). The app should
  interpret a 500 on a first-ever brief as **"sync your health data first"** and guide the user to
  complete HealthKit auth + sync, rather than showing a scary error.
- **`intakeYesterday = null`** → "no food logged yesterday" empty state (§7.4.5).
- **`nutrition.lastWeek = null`** → "not enough history yet" on the weekly adherence card.
- **`budgets.longRunKm = null`** → omit the long-run target gracefully.
- **Partial HealthKit grants** → the brief still generates but with lower fidelity; consider a subtle
  "we're missing X data" hint where a field is conspicuously absent.

### 8.6 Edge-case catalogue (quick reference)

| Edge case | Expected UX |
|---|---|
| User opens app twice in a morning | 2nd brief is **cached** (instant, same content). Sync returns 0 upserts. No error. |
| User edits the check-in after generating the brief | Re-sync; offer **Refresh** to regenerate the brief off the corrected check-in. |
| Safety gate fires | **Forced-REST 200** screen (§7.4.2), not an error. AI skipped, alternatives empty. |
| Knee pain > 3 | No running/jumping in the suggestion; impact cards blocked; low-impact substitute shown. |
| New ISO week | Trigger the **weekly** brief (may also recompute constants → a touch slower). "New week" moment. |
| Travel / DST change | Periods resolve in Europe/Sofia; "today" may shift vs device local time — display the server frame consistently. |
| No new HealthKit data to sync | Sync succeeds with zero counts; proceed to brief. |
| Strength test re-entered same week | Latest overwrites; trend uses the new value. |
| Long, slow brief generation | Spinner up to ~60 s; if it times out → 504, friendly retry. |
| Refresh spam | Each refresh re-runs the AI (a few seconds each); consider debouncing the Refresh control. |
| Food logged late (after the brief) | `intakeYesterday` only reflects what was in HealthKit at generation time; a Refresh picks up newly-synced intake. |

---

## 9. Content & copy

### 9.1 Narrative rendering rules

- **All coaching prose comes from `narrative[]`.** The app renders sections **in order**, styled by
  `type` (§4.5). It must **not** write its own coaching sentences. Numbers/labels in the UI come from
  `data`; explanations/encouragement come from `narrative`.
- Bodies are markdown/plain — render basic markdown (emphasis, lists).
- Place `summary`/`plan` as the lead, `session` by the workout, `nutrition` in the nutrition area,
  `caution` set apart (§9.2).
- The coach voice is supportive, specific, and concise. Mirror that in surrounding microcopy.

### 9.2 Medical-aware caution & nutrition copy

The user has several managed conditions. These are **LLM context, not a code-enforced medical layer** —
they shape the coach's *words*, surfaced through `nutrition` and `caution` narrative sections. The app
**flags, never diagnoses or prescribes medication.** The designer should give caution copy a calm,
trustworthy, non-alarming treatment (set-apart card, soft accent — not red-alert), and ensure
nutrition copy has room to carry food-specific guidance. The conditions a designer should be aware of
(so the tone fits):

| Condition | How it shows up in copy the user sees |
|---|---|
| **Ulcerative proctitis (UC), in remission** | The daily GI check-in; on a flag, a forced-REST/deload + "low-residue eating" nutrition note; "if persistent/bloody, see a doctor." |
| **NSAID-free (hard rule)** | Any pain advice offers only ice / topical / paracetamol / load management — **never ibuprofen/NSAIDs.** |
| **Lactose intolerance** | Protein guidance steers to lactose-safe sources (Greek yogurt, kefir, hard cheese, whey *isolate* / plant) and away from milk / whey *concentrate*. |
| **GERD / gastritis / duodenitis** | "Don't train hard on a full stomach"; finish meals ≥3 h before lying down; limit coffee/spicy/acidic/carbonated/alcohol. |
| **Biliary dyskinesia (gallbladder)** | "Spread fat across meals; avoid large greasy/fried boluses." |
| **Constipation-prone (dolichosigma/hemorrhoids)** | Soluble-fiber-forward + strong hydration; ease off raw/insoluble fiber around hard sessions/flares. |
| **Kidney microliths (stones)** | High hydration, citrate (lemon water), calcium with meals, moderate sodium, don't megadose protein/vitamin C. |

**Refer-to-doctor flags** the coach may raise (the app surfaces as calm `caution` notes, never as
diagnoses): rectal bleeding, fever + GI symptoms, flank pain / blood in urine, chest pain / HR
anomalies, joint swelling.

### 9.3 Tone do/don't

- **Do**: "Keep it easy today — your gut needs a break." / "It's fine to skip; rest is training too."
- **Do**: frame the easy-pace cap as intentional ("this will feel slow — that's the point").
- **Don't**: gamified guilt ("you broke your streak!"), red-alert medical framing, or implying the app
  diagnoses.
- **Don't**: surface raw machine keys (`hrv_below_baseline`, `gi_flare`, `quality_day`) — always
  translate (see §12).

### 9.4 Accessibility & micro

Color-band semantics (green/amber/red) must not be the *only* signal — pair with labels/icons for
color-blind users. Numbers (HR cap, cadence, macros) should be legible at a glance and during a run
(large, high-contrast). Hydration/protein are recurring "did I hit it" checks — make them scannable.

---

## 10. Out of scope (v1) — do not design screens for these

- **Accounts, sign-up, multi-user, social, sharing** — single user by architecture.
- **In-app food logging** — food is logged in a third-party app → HealthKit; the app only *reads* it.
- **Manual workout logging** — workouts come from HealthKit.
- **Manual body-weight entry** — weight is HealthKit `body_mass`.
- **Server push notifications / reminders / scheduling** — the backend has no scheduler and sends
  nothing. Any reminder is an app-local notification the product opts into (§11).
- **Streaming/typewriter brief text** — briefs arrive as a complete object after a spinner.
- **A medical/PDF/records feature** — medical docs are build-time context only; never user-facing.
- **A web/Android client** — iOS only.

## 11. Open product questions (need a decision before final design)

1. **Trends/History (§7.6):** v1 in scope? If yes, source = app-accumulated brief data + HealthKit, or
   a *new* backend endpoint (not currently planned)? This gates a whole section of screens.
2. **Local reminders:** does v1 want an app-scheduled "good morning, check in" / "log your strength
   test" local notification? The server won't send anything — it must be app-side if wanted.
3. **Token onboarding:** how does the single user receive/enter the API token (paste, QR, provisioned
   build)? Affects the connect screen.
4. **Daily brief availability:** the daily brief (the hero) is the next backend epic in flight — confirm
   the design timeline assumes it. Weekly + sync are live today.
5. **Cadence metronome:** is a live in-run cadence cue (using `cadenceSpm`) in v1, or display-only?
6. **Degraded HealthKit:** how aggressively should the app insist on full permissions vs run degraded?

---

## 12. Appendix — enum → UX label reference

The app must **never** show raw machine keys. Suggested human labels (the designer can refine wording;
the *mapping* is what matters):

### 12.1 Workout cards → labels

| `card` | Suggested label | Notes for display |
|---|---|---|
| `easy_run` | Easy run | Z2, HR cap, cadence cue, run/walk OK |
| `long_run` | Long run | effort-based (run by feel), the marquee endurance session |
| `progression_run` | Progression run | starts easy, finishes faster; needs healthy knee |
| `threshold` | Threshold run | "comfortably hard," Z4 |
| `vo2` | VO₂ intervals | hardest run; needs healthy knee |
| `strides` | Strides | short add-on to an easy run, not standalone |
| `active_recovery` | Active recovery | gentle walk/spin/row/mobility |
| `hiit` | HIIT | conditioning intervals |
| `jump_rope` | Jump rope | knee-capped; small doses |
| `steady_cardio` | Steady cardio | low-impact bike/row/elliptical |
| `strength_push` | Push strength | chest/shoulders/triceps |
| `strength_pull` | Pull strength | back/biceps + posture |
| `strength_lower` | Lower strength | legs / knee support |
| `strength_full` | Full-body strength | time-crunch option |
| `boxing` | Boxing | a hard day; high recovery cost |
| `boxing_technique` | Boxing (technique) | light skill version for tired days |
| `foot_prehab` | Foot prehab | 5–10 min add-on (flat feet) |
| `glute_prehab` | Glute prehab | 5–10 min add-on (knee tracking) |
| `mobility` | Mobility | recovery/range; pre-bed OK |
| `rest` | Rest | full rest |

### 12.2 Flags → meaning (surface as quiet badges/footnotes)

| flag | User-facing meaning |
|---|---|
| `impact` | High-impact — affected by knee status |
| `needs_green_knee` | Only when the knee is healthy |
| `low_impact` / `prefer_low_impact` | Knee-friendly option |
| `knee_amber_cap` | Allowed only up to mild knee discomfort |
| `append_to_easy` | Add-on to an easy run, not its own session |
| `effort_based` | Run by feel, not a hard HR ceiling |
| `auto_reg_downgrade` | The easier version of a harder session |
| `big_recovery_cost` | Costs a lot of recovery — space it out |
| `prehab:foot` / `prehab:glute` | A small prehab add-on |
| `quality_day` | A hard day (counts against the hard-day budget) |

### 12.3 Other enums

| Enum | Values → labels |
|---|---|
| **Readiness band** | `green` → Ready · `amber` → Compromised (ease off) · `red` → Recover (don't push) |
| **Day type** | `hard` → Carb-load · `moderate` → Standard · `rest` → Lower-carb (deficit) |
| **Intensity** | `easy` · `quality` → Hard · `recovery` |
| **Zone** | `z1`–`z5` (show the HR range) |
| **Tier** | `core` → Do these · `extra` → Optional |
| **Weekday** | `mon`…`sun` |
| **Penalty factor** | `sleep_below_7h` → Short sleep · `sleep_below_5h` → Very short sleep · `hrv_below_baseline` → HRV below baseline · `rhr_above_baseline` → Resting HR elevated · `yesterday_hard_day` → Hard session yesterday |
| **Safety reason** | `gi_flare` → Gut flare · `illness` → Feeling unwell · `knee_pain_high` → Knee pain high · `sleep_below_4h` → Very little sleep · `rhr_spike` → Resting HR spike · `hrv_crash` → HRV drop |
| **Narrative type** | `summary` · `session` · `nutrition` · `caution` · `plan` |
| **Error code** | `unauthorized` · `validation_error` · `not_found` · `brief_generation_failed` · `upstream_timeout` · `internal_error` |

---

*Sources: `docs/architecture/ARCHITECTURE.md`, `MODELS.md`, `CARDS.md`, `LLM.md`,
`HEALTH-CONSITTUTION.md`, `profile.yaml`, and the E1–E12 epic/plan artifacts. Where this PRD and the
current backend differ (the daily-brief endpoint and a trends endpoint), it is flagged inline (§0
caveat, §7.6, §11). The `.md` design docs are the source of truth for the wire contract.*
