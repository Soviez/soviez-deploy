# DATA_EGRESS_MODEL.md

## Never to SaaS

Database/dumps; filestore; attachments; addon source; customer/employee/accounting records; passwords; private keys; TLS private keys; DNS provider credentials; unrestricted logs; source web traffic; backup/migration payloads.

## Permitted minimal connected metadata (only when necessary)

| Field | Purpose |
|-------|---------|
| account_id | Binding |
| license_id | Binding |
| migration_pair_id | Binding |
| source_environment_id | Binding |
| destination_bootstrap_id | Binding |
| domain / migration_fqdn | Challenge context |
| dns_challenge_token_hash (not raw secret if avoidable) | Verify assist — prefer fully local |
| certificate_status | Non-sensitive |
| routing_status | Non-sensitive |
| operation_status | Ops |
| timestamps | Ops |
| idempotency_key | Ops |
| public_fingerprints | Trust |
| challenge_expiry | Ops |
| validation_result | Ops |

**Default stance:** Phase 18 is **local-first**. SaaS calls are optional and must be allowlisted; no periodic phone-home; no SaaS proxy of customer traffic; no DNS credentials in SaaS.

Document each connected field in implementation evidence before enabling.
