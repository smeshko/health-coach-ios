import BriefRepository
import DomainModels
import SyncRepository

/// The single source of truth for the Today screen's lifecycle (PRD §8.1, DECISIONS #1) — a closed enum
/// switched **exhaustively** (no `default:`) in the reducer and view, so a later phase adding *content*
/// to a `ready` brief can never silently miss a lifecycle render path.
///
/// `idle → checkInRequired? → syncing → generating → ready(fresh|cached) → {syncFailed | error}`. The
/// check-in **gates** the chain (the 2026-06-10 design iteration): with no check-in saved today the
/// orchestration stops at `checkInRequired` — the check-in screen, no sync — and "Save & build today's
/// brief" re-enters the chain. Forced-REST and Empty are **content of a `ready` brief**
/// (`safetyGate.triggered`, `intakeYesterday == nil`) rendered by Phases 8.2/8.4 — not separate lifecycle
/// cases. `syncFailed` and `error` are distinct terminals (DECISIONS #3): a sync failure blocks the brief
/// (block-and-retry, D23/§8.2), a brief failure is a generation/transport error. Each terminal carries
/// the typed domain error as-is — the human copy + Retry affordance is the `DesignSystem` presentation
/// boundary's job, not this model's.
public enum BriefViewState: Equatable, Sendable {
  case idle
  case checkInRequired
  case syncing
  case generating
  case ready(DomainModels.DailyBrief, Freshness)
  case syncFailed(SyncError)
  case error(BriefError)
}

/// Whether a `ready` brief was served fresh (this request generated it) or from the same-day cache
/// (PRD §8.2 — the `cached` flag drives the "as of HH:MM" label, never the spinner decision).
public enum Freshness: Equatable, Sendable { case fresh, cached }
