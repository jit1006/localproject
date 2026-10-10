# Decision log

Each entry: decision · rationale · source · reversible?

## Stack
- **FastAPI + SQLAlchemy + PostgreSQL + React/Vite/TS.** Matches the brief's
  recommended stack (§9). Reversible: yes, but no reason to change.
- **No `metadata.create_all`.** The SQL files are the single schema authority
  (brief §10). ORM maps a subset. Reversible: no (invariant).

## Auth
- **Server-side sessions, SHA-256 token digest, HttpOnly cookie.** Avoids storing
  bearer tokens; satisfies the brief's hashed-password/secure-cookie requirement.
  Reversible: could swap to signed JWT, but server-side revocation is preferred.

## Events
- **Single `event_log`, projections rebuilt from it.** Brief invariant (§10/§11).
- **Idempotency keys derived server-side** (`create:`, `request:`, `destroy:` …).
  Prevents duplicate actions on retry. Reversible: could accept client keys via
  an `Idempotency-Key` header later.
- **`occurred_at, event_id` replay order.** Deterministic tie-breaker; source
  event id is not treated as chronological (brief §11).

## Compliance
- **Destruction eligibility re-checked at execution**, not only at request time —
  a hold applied after approval still blocks (acceptance criterion).
- **Approver ≠ requester** enforced in the service (separation of duties).

## Branch name
- Requested branch "complete project" contains a space, which git disallows, so
  the branch is **`complete-project`**. Reversible: rename on request.

## Source-conflict handling (carried from brief §8, to resolve during engines)
| Conflict | Interim handling |
|---|---|
| Transit 3 business days vs 30 calendar-day suspected-loss | Keep both as configurable `threshold_rule`; distinguish delay from loss finding |
| Destruction SLA approval→certificate vs separate windows | Store execution + certificate timestamps; workbook definition provisional |
| Certificate reuse across batches vs misuse | Allow repeats within a legitimate vendor/month batch; flag cross-vendor/month |
| No return rate in rate card | Report missing rate; never substitute zero or pickup rate |
| Tax 18% with no start date | Configure explicit date range in `tax_rule`; don't invent history |
| Entity/vendor overrides vs general reference | Support scoped overrides over global defaults; don't invent overrides |

## Honesty
- No test pass, run result, reconciliation count, or benchmark is claimed that
  was not actually produced. Environment limitations are stated where they
  prevented execution (brief §17).
