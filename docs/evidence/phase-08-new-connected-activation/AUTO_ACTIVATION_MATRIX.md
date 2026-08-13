# AUTO_ACTIVATION_MATRIX — Phase 8

**Module:** `src/license/activate_orm.sh`  
**Orchestration:** `src/commands/new.sh` (automatic branch)

## Flow

| Step | Action | State |
|------|--------|-------|
| 1 | User/default selects `--activation automatic` | `waiting_for_activation_method` |
| 2 | `soviez_slots_issue_license` returns key | `license_issued` |
| 3 | Key stored 0600 locally | — |
| 4 | Transition | `activation_pending` |
| 5 | `soviez_license_activate_via_odoo` | ORM call |
| 6 | Success | `activated` |
| 7 | `soviez_license_send_activation_ack` | SaaS notified |
| 8 | Validate + complete | `completed` |

## ORM invocation pattern (production)

1. `printf '%s' "$activation_key" | docker exec -i` → staging file mode 0600 inside container
2. `odoo shell -d "$db_name"` → `env["soviez.license.mixin"].action_activate_soviez_license(key)`
3. Staging file overwritten + unlinked
4. Remote cleanup on failure

**Key never in argv or logs.**

## Test certification

| Test | Stub | Assertion | Result |
|------|------|-----------|--------|
| `test_new_automatic_path.sh` | `SOVIEZ_ODOO_STUB=odoo_activate_stub.sh` | Final state `completed` | PASS |
| | | Stub marker exists | PASS |
| | | Mock key `SOV-MOCK-KEY-0001` not in events.jsonl | PASS |
| `test_secret_handling.sh` | — | 0600 storage, redaction | PASS |

## Test substitutes

| Mode | Behavior |
|------|----------|
| `SOVIEZ_ODOO_STUB` | Stub reads stdin; writes marker without key |
| `SOVIEZ_TEST_MODE=1` (no stub) | Writes `stubs/activation-<db>.invoked` |

## PARTIAL gap

Production path code present and reviewed. **Full disposable Odoo ERP container** running real `odoo shell` with `action_activate_soviez_license` **not exercised** in certification environment.

This is the sole acceptance gate preventing full PASS.
