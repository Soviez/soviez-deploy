# OPERATION_STATE_MACHINE — Phase 8

**Implementation:** `src/operations/state_machine.sh`  
**Schema:** `schemas/new_operation_state.schema.json`

## States (29)

| # | State | Description |
|---|-------|-------------|
| 1 | `created` | Operation initialized |
| 2 | `preflight` | Host checks running |
| 3 | `waiting_for_connection_consent` | User disclosure pending |
| 4 | `device_authorization_pending` | Browser auth in progress |
| 5 | `device_authorized` | Device credential obtained |
| 6 | `slot_reserved` | License Slot held |
| 7 | `release_resolved` | ERP release digest known |
| 8 | `image_pull_authorized` | Pull session created |
| 9 | `image_pulled` | Image at pinned digest |
| 10 | `tenant_identity_created` | Tenant UUID assigned |
| 11 | `database_provisioned` | PostgreSQL DB ready |
| 12 | `container_started` | ERP container running |
| 13 | `domain_pending` | Domain config started (optional) |
| 14 | `waiting_for_dns` | DNS propagation wait |
| 15 | `ssl_pending` | Certificate issuance |
| 16 | `instance_provisioned` | SaaS notified of provision |
| 17 | `fingerprint_bound` | Hardware+UUID fingerprint bound |
| 18 | `waiting_for_activation_method` | Auto/manual choice recorded |
| 19 | `license_issued` | Activation key issued to server |
| 20 | `activation_pending` | About to activate |
| 21 | `activated` | ORM activation complete (auto) |
| 22 | `manual_activation_pending` | Awaiting user portal activation |
| 23 | `validating` | Post-activation checks |
| 24 | `completed` | Automatic path terminal |
| 25 | `completed_activation_pending` | Manual path terminal |
| 26 | `canceled` | User/operator canceled |
| 27 | `failed_retryable` | Retry allowed |
| 28 | `recovery_required` | Operator intervention |
| 29 | `failed_terminal` | Unrecoverable |

## Automatic path transitions

```
created → preflight → waiting_for_connection_consent → device_authorization_pending
→ device_authorized → slot_reserved → release_resolved → image_pull_authorized
→ image_pulled → tenant_identity_created → database_provisioned → container_started
→ [domain_pending → waiting_for_dns → ssl_pending →] instance_provisioned
→ fingerprint_bound → waiting_for_activation_method → license_issued
→ activation_pending → activated → validating → completed
```

## Manual path divergence

At `activation_pending`: → `manual_activation_pending` → `completed_activation_pending`

## Resume semantics

`soviez_sm_should_run_step(current_state, step_name)` returns false for already-completed steps.

Certified: resume from `device_authorization_pending` → `completed` (`test_disconnect_resume.sh`).

## Failure transitions

Any state may transition to: `failed_retryable`, `failed_terminal`, `canceled`, `recovery_required`

## Unit test

`tests/unit/test_state_machine.sh` — valid/invalid transition matrix.
