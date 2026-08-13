# OPERATION_ENGINE_MODEL.md

## Proposed operation types

| Type | Purpose |
|------|---------|
| `migration_domain_plan` | Pair validate; inspect source; select strategy; emit plan |
| `migration_dns_challenge` | Generate/sign challenge; await DNS |
| `migration_dns_validation` | Authoritative/public checks (also used by Try Again) |
| `migration_landing_prepare` | Nginx + landing + health |
| `migration_tls_prepare` | CAA/ACME/store/verify mig cert |
| `migration_routing_readiness` | Compose signed routing plan/report |
| `migration_domain_abort` | Exact abort/cleanup |

## Suggested state machines

### Domain plan
`created → validating_pair → inspecting_source_domain → inspecting_source_certificate → selecting_domain_strategy → producing_domain_plan → completed`

### DNS challenge
`created → generating_challenge → signing_challenge → awaiting_dns_record → checking_authoritative_dns → checking_public_dns → validating_binding → completed`

### Landing
`created → validating_destination → preparing_landing → validating_nginx → starting_landing → health_checking → completed`

### TLS
`created → validating_domain_proof → checking_caa → creating_acme_order → completing_challenge → issuing_certificate → validating_chain → storing_certificate → completed`

### Routing readiness
`created → loading_domain_plan → validating_landing → validating_tls → validating_health → validating_source_unchanged → producing_routing_plan → completed`

## Shared failure states

`failed_retryable` | `retry_scheduled` | `recovery_required` | `failed_terminal` | `canceled` | `aborted`

## Reboot / recovery

All durable state under `$SOVIEZ_MIG_ROOT/domain/` (proposed). After reboot: incomplete ACME → `recovery_required`; completed irreversible checkpoints (issued challenge id, stored cert paths) not duplicated; ambiguous mid-flight → recover CLI.

## CLI proposal (not implemented)

```bash
sudo soviez.sh --migration-domain-plan <pair-id>
sudo soviez.sh --migration-domain-plan-show <plan-id>
sudo soviez.sh --migration-landing-prepare <pair-id>
sudo soviez.sh --migration-landing-status <operation-id>
sudo soviez.sh --migration-dns-challenge <pair-id> --domain <domain>
sudo soviez.sh --migration-dns-show <challenge-id>
sudo soviez.sh --migration-dns-try-again <challenge-id>
sudo soviez.sh --migration-dns-abort <challenge-id>
sudo soviez.sh --migration-tls-prepare <pair-id> --domain <domain>
sudo soviez.sh --migration-tls-status <operation-id>
sudo soviez.sh --migration-routing-readiness <pair-id>
sudo soviez.sh --migration-routing-show <report-id>
sudo soviez.sh --migration-domain-abort <pair-id>
sudo soviez.sh --migration-status <operation-id>
sudo soviez.sh --migration-reattach <operation-id>
sudo soviez.sh --migration-retry <operation-id>
sudo soviez.sh --migration-recover <operation-id>
```

Exact IDs; interactive confirm; `--yes` for non-TTY; JSON on stdout; stable exit via `SOVIEZ_ERR_MIGRATION`; local/connected/offline modes; no automatic Production cutover.
