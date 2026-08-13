# Migration Pair Object — Phase 17

Canonical **local** object (schema versioned). Sensitive material stays on hosts; SaaS receives only allowlisted metadata if connected.

## Minimum fields

| Field | Notes |
|-------|-------|
| `schema_version` | e.g. `soviez.migration_pair.v1` |
| `migration_pair_id` | ULID/UUID |
| `source_production_id` | Exact |
| `source_license_id` | Exact |
| `source_host_identity` | Fingerprint |
| `source_database_uuid` | Exact |
| `source_image_digest` | Pin |
| `destination_bootstrap_id` | Temporary |
| `destination_host_identity` | Fingerprint |
| `destination_architecture` | |
| `destination_os` | |
| `destination_installer_version` | Exact |
| `destination_readiness_state` | |
| `source_discovery_snapshot_id` | |
| `compatibility_result` | PASS/WARNING/BLOCKED summary |
| `trust_certificate_refs` / fingerprints | Refs, not private keys in clear logs |
| `created_at` / `expires_at` | OD-06/18 |
| `owner_approval_state` | pending/approved/revoked |
| `migration_token_eligibility_state` | eligible / ineligible / unknown |
| `migration_token_consumed` | **always `false` in Phase 17** |
| `data_transfer_started` | **`false`** |
| `dns_changed` | **`false`** |
| `source_maintenance_enabled` | **`false`** |
| `destination_activated` | **`false`** |
| `status` | draft/trusted/ready/blocked/aborted/expired |
| `failure_code` | Structured code |
| `recovery_state` | |
| `abort_state` | |

## Persistence

- Local encrypted/0600 directory under migration ops root  
- Indexed by Phase 14 ops when bound to an operation  
- Expiry invalidates trust for later phases until re-pair  

## Non-goals

Object must not embed DB dumps, filestore, secrets, or SSH private keys.
