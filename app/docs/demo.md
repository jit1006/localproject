# Ten-minute demo script

Prerequisites: schema + seed applied, backend on :8000, frontend on :5173, and
one user per role provisioned (`scripts/create_user.py`).

Provision demo users (adjust passwords):

```bash
cd backend
python -m scripts.create_user U-BIZ "Dina Business" dina@example.com BUSINESS \
  --password 'demo' --entity ENT-BRN --department DEP-BRN-DEL
python -m scripts.create_user U-VND "Victor Vendor" victor@securevault.example VENDOR \
  --password 'demo' --vendor VND-001
python -m scripts.create_user U-CMP "Carla Compliance" carla@example.com COMPLIANCE --password 'demo'
python -m scripts.create_user U-FAC "Fay Facilities" fay@example.com FACILITIES --password 'demo'
```

## Script

1. **Problem & roles (1m).** Sign in as each role; show the navigation changes
   per role (Vendor sees only its queue; Facilities sees Reconciliation).

2. **Pickup & receipt (2m).** As Business, register a carton and raise a Pickup.
   As Vendor, Acknowledge → Collect → Receive at warehouse. Point out the carton
   history: *collection is a separate event from warehouse receipt*; only after
   receipt is the status **In Storage**.

3. **Retrieval & history (2m).** As Business, raise a Retrieval; as Vendor,
   Deliver. Show the carton detail history reconstructed from the event log.

4. **Retention edit & hold refusal (2m).** Open a carton's retention (from the
   view). Edit a `retention_policy` row directly in SQL and refresh — the due date
   changes with no code change. As Compliance, apply a legal hold; then as
   Business attempt a destruction request → it is refused.

5. **Reconciliation evidence (2m).** As Facilities, start a reconciliation run;
   show it recorded with who/when/scope and that re-running the same scope
   deduplicates. (Full detection engines are the next increment — be explicit.)

6. **Access denial & limitations (1m).** As Vendor, try to open a carton's files
   → forbidden (contents are never exposed to vendors). As Business, try to view
   another department's carton → forbidden. Close by naming the known limitations
   from `docs/tasks.md`.

> Use an eligible supplied historical carton for the destruction path. Do not
> fabricate source results to improve the presentation. If live execution fails,
> fall back to a recorded run and label it clearly.
