# PRMS API contract

Base prefix: **`/api/v1`**. Auth is a session cookie (`prms_session`, HttpOnly).
Send `credentials: include`. Interactive docs at `/docs` when the server runs.

## Error shape

```json
{ "error": { "code": "FORBIDDEN", "message": "…", "fieldErrors": {}, "correlationId": "…" } }
```

Codes: `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404),
`CONFLICT` (409), `UNPROCESSABLE` (422).

## Idempotency

State-changing carton commands derive a stable idempotency key server-side (e.g.
`create:<cartonId>`, `request:<requestId>`, `destroy:<requestId>`). Replaying the
same logical command returns the original event rather than creating a duplicate.

## Endpoints

### Auth
| Method | Path | Role | Body / notes |
|---|---|---|---|
| POST | `/auth/login` | any | `{email, password}` → sets cookie, returns user |
| POST | `/auth/logout` | any | clears cookie |
| GET | `/auth/me` | authed | current user |

### Cartons
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/cartons` | BUSINESS | register carton |
| GET | `/cartons/{id}` | scoped | view (row-scope enforced) |
| POST | `/cartons/{id}/files` | BUSINESS | index a file |
| GET | `/cartons/{id}/files` | not VENDOR | list files (vendor forbidden) |
| GET | `/cartons/{id}/history` | scoped | state + event log |
| GET | `/cartons/{id}/retention` | scoped | from `carton_retention` view |

### Requests
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/requests` | BUSINESS | raise PICKUP/RETRIEVAL/RETURN/DESTRUCTION |
| GET | `/requests/queue` | VENDOR | own-vendor queue |
| POST | `/requests/{id}/acknowledge` | VENDOR | |
| POST | `/requests/{id}/collect` | VENDOR | collection ≠ receipt |
| POST | `/requests/{id}/receive` | VENDOR | warehouse receipt → In Storage |
| POST | `/requests/{id}/deliver` | VENDOR | retrieval delivery |
| POST | `/requests/{id}/approve` | COMPLIANCE | destruction, approver ≠ requester |
| POST | `/requests/{id}/destroy` | VENDOR | re-checks hold at execution |

### Holds
| Method | Path | Role |
|---|---|---|
| GET | `/holds?active_only=` | COMPLIANCE/FACILITIES |
| POST | `/holds` | COMPLIANCE |
| POST | `/holds/{id}/release` | COMPLIANCE |

### Reconciliation & exceptions
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/reconciliations` | FACILITIES | idempotent by kind+scope+fingerprint |
| GET | `/reconciliations` | FACILITIES | list runs |
| GET | `/exceptions` | scoped | vendor sees own redacted only |

### Dashboard & reference
| Method | Path | Role | Notes |
|---|---|---|---|
| GET | `/dashboard` | any | counts scoped to role |
| GET | `/reference-data/vendors` | any | vendor list |

### Health
| Method | Path | Notes |
|---|---|---|
| GET | `/health` | liveness + DB connectivity (no `/api/v1` prefix) |
