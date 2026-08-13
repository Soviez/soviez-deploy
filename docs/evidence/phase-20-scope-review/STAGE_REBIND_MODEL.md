# STAGE_REBIND_MODEL.md

For each selected migrated Stage:

- Exact source Stage ID ↔ destination Stage staging ID
- Parent License + Production transition binding
- Stage entitlement; retention deadline **unchanged**; no auto-extension; no silent new entitlement
- Public routing disabled; source Stage protected until 21/22 policy
- Optional rebind failure → **WARNING**; mandatory → **BLOCKED**
- No Stage selected by default; expired remains denied; wrong-parent denied
- Exact + idempotent rebind; cross-tenant denied
