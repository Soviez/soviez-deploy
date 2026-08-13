# Operation Engine Model — Phase 17

Integrate with Phase 14 unified ops. Proposed types:

| Type | Purpose |
|------|---------|
| `migration_source_discovery` | Exact-source inventory |
| `migration_destination_bootstrap` | Dest preflight + init + temp identity |
| `migration_trust_pairing` | Challenge/confirm/pair cert |
| `migration_readiness_assessment` | Compatibility + report |
| `migration_pair_abort` | Idempotent abort |

Foreshadowed short name `migrate` in `conflicts.sh` should map to these types (or a parent aggregate) without colliding with `src/ops/migration.sh` schema remapper.

## Source discovery states

```text
created
→ validating_source
→ collecting_identity
→ collecting_runtime
→ collecting_capacity
→ collecting_addon_inventory
→ collecting_stage_inventory
→ collecting_network_readiness
→ writing_discovery_report
→ completed
```

## Destination bootstrap states

```text
created
→ validating_destination_host
→ verifying_installer
→ installing_runtime_prerequisites
→ initializing_destination
→ registering_temporary_identity
→ validating_destination
→ completed
```

## Trust pairing states

```text
created
→ generating_challenge
→ awaiting_owner_confirmation
→ verifying_source
→ verifying_destination
→ issuing_pair_certificate
→ validating_pair
→ completed
```

## Readiness states

```text
created
→ loading_source_discovery
→ loading_destination_bootstrap
→ validating_trust
→ checking_compatibility
→ checking_capacity
→ checking_connectivity
→ checking_commercial_eligibility
→ producing_readiness_report
→ completed
```

## Failure / terminal

`failed_retryable`, `retry_scheduled`, `recovery_required`, `failed_terminal`, `canceled`, `aborted`

## CLI adapters (proposed)

`--migration-status|reattach|retry|recover` reuse Phase 14 unified adapters.
