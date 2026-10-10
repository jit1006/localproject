# Role × permission matrix

Legend: ✔ allowed · ✖ denied · (scope) row-scoped

| Capability | Business | Vendor | Compliance | Facilities |
|---|---|---|---|---|
| Log in | ✔ | ✔ | ✔ | ✔ |
| View carton | ✔ (own dept) | ✔ (own vendor) | ✔ (all) | ✔ (all) |
| View carton **contents** (files) | ✔ (own dept) | ✖ | ✔ | ✔ |
| Register carton / index files | ✔ | ✖ | ✖ | ✖ |
| Raise pickup/retrieval/return | ✔ (own dept) | ✖ | ✖ | ✖ |
| Raise destruction request | ✔ (own dept) | ✖ | ✖ | ✖ |
| Acknowledge / collect / receive / deliver | ✖ | ✔ (own vendor) | ✖ | ✖ |
| Execute destruction + lodge certificate | ✖ | ✔ (own vendor) | ✖ | ✖ |
| Approve / reject destruction | ✖ | ✖ | ✔ (≠ requester) | ✖ |
| Apply / release legal hold | ✖ | ✖ | ✔ | ✖ |
| View legal holds | ✖ | ✖ | ✔ | ✔ |
| Run reconciliation | ✖ | ✖ | ✖ | ✔ |
| View exceptions | own-scoped (planned) | own vendor, redacted | ✔ | ✔ |
| View rates / costs | ✖ | ✖ | ✖ | ✔ |
| User admin / reference maintenance | ✖ | ✖ | ✖ | ✔ (planned) |

## Enforcement points

- **Role** — `deps.require_roles(...)` on the router.
- **Row scope** — `services/scope.py` (`assert_can_view_carton`,
  `assert_can_raise_for_carton`, `assert_can_act_on_request`).
- **Field redaction** — vendor users are refused carton contents in
  `carton_router.list_files`; exception visibility filtered in
  `reconciliation_router.list_exceptions`.
- **Separation of duties** — destruction approver must differ from requester
  (`request_service.approve_destruction`).

All checks are server-side. The frontend hides controls for usability only; it is
never the authority.
