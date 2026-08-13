# Systemd Contract

**Phase:** 14  
**Verdict:** PASS  

## 1. Standardization Contract

While command engines preserve their custom service unit layout strategies (certified across Phase 8 and 11), Phase 14 standardizes naming, environment hygiene, and teardown boundaries in `src/ops/systemd.sh`:

- **Naming Standard:** Service units are structured as:
  `soviez-op-<operation_id>.service`
- **Environment Isolation:** Standard worker variables are stored under a restricted file at:
  `$SOVIEZ_OPS_ROOT/operations/<id>/worker.env`
  This file is protected with `0600` permissions. It is populated strictly with non-secret identifiers (`SOVIEZ_OPERATION_ID`, `SOVIEZ_OPS_CANONICAL`, `SOVIEZ_OPS_ROOT`). No credentials or database passwords are ever written to environment files.
- **Hygiene & Cleanup:** When an operation completes, `soviez_ops_systemd_cleanup_terminal` disarms and disables the unit, then removes the unit definition file from `/etc/systemd/system/` to prevent host clutter.
