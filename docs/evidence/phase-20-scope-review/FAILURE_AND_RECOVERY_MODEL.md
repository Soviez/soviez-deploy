# FAILURE_AND_RECOVERY_MODEL.md

## Happy path states

```text
created → validating_phase19 → validating_entitlement → locking_license
→ locking_token → preparing_authorization → committing_token_and_binding
→ authorization_committed → applying_destination_binding → applying_source_grace
→ rebinding_stages → validating_destination_activation → validating_split_brain_guards
→ producing_phase21_readiness → completed
```

## Failure / recovery

| State | Meaning |
|-------|---------|
| `failed_precommit` | Safe retry; token available |
| `canceled_precommit` / `aborted_precommit` | Safe |
| `commit_status_unknown` | Query by idempotency; do not double-consume |
| `authorization_committed_local_apply_pending` | Retry local apply |
| `destination_apply_failed` / `source_grace_apply_failed` | Recovery required; Phase 21 blocked |
| `stage_rebind_partial` | WARNING or BLOCKED per mandatory/optional |
| `recovery_required` / `compensation_required` | Explicit ops |
| `failed_terminal` | No silent continue |

No ordinary cancellation after authoritative commit.
