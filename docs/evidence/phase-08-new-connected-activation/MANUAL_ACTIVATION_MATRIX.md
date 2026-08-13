# MANUAL_ACTIVATION_MATRIX — Phase 8

**Module:** `src/license/choice.sh`  
**Orchestration:** `src/commands/new.sh` (manual branch)

## Flow

| Step | Action | State |
|------|--------|-------|
| 1 | User selects `--activation manual` | `waiting_for_activation_method` |
| 2 | `soviez_slots_activation_method` records `manual` | — |
| 3 | `soviez_slots_issue_license` | `license_issued` |
| 4 | Key stored 0600 (for later user use) | — |
| 5 | Transition | `activation_pending` |
| 6 | Skip ORM | `manual_activation_pending` |
| 7 | Terminal | `completed_activation_pending` |

## Invariants preserved

| Invariant | Status |
|-----------|--------|
| Manual portal path unchanged | ✅ |
| No ORM call on manual | ✅ |
| License still issued to server | ✅ |
| User activates via portal later | ✅ (documented) |
| Slot reservation chain complete | ✅ |

## Test certification

| Test | Result |
|------|--------|
| `test_new_manual_path.sh` | **PASS** — final state `completed_activation_pending` |

## User documentation

Updated: `docs/user/LICENSE_ACTIVATION.md`, `docs/user/INSTALLATION.md`

## Comparison

| Aspect | Automatic | Manual |
|--------|-----------|--------|
| ORM call | Yes | No |
| Activation ack to SaaS | Yes | No (pending user action) |
| Terminal state | `completed` | `completed_activation_pending` |
| Login ready (licensed) | Yes (if ORM succeeds) | No — user must paste key |
