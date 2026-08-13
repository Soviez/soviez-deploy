# IMPLEMENTATION_DECOMPOSITION.md

**Do not implement now.** Proposed modular layout:

```text
src/migration/domain/
  codes.sh
  model.sh
  targeting.sh
  strategy.sh
  source_inspection.sh
  plan.sh
src/migration/dns/
  challenge.sh
  signing.sh
  authoritative.sh
  public_resolvers.sh
  dnssec.sh
  reachability.sh
  retry.sh
  abort.sh
src/migration/landing/
  content.sh
  container.sh
  nginx.sh
  headers.sh
  health.sh
  cleanup.sh
src/migration/tls/
  policy.sh          # wraps/extends src/ssl/policy.sh
  acme.sh            # wraps src/ssl/provider.sh
  caa.sh
  storage.sh
  verify.sh
  renew.sh
  revoke.sh
src/migration/routing/
  source_guard.sh
  destination_plan.sh
  readiness.sh
  report.sh
  abort.sh
src/migration/commands/
  domain_plan.sh
  dns.sh
  landing.sh
  tls.sh
  routing.sh
```

Reuse without forking: `src/ssl/challenge.sh` patterns, `src/nginx/ownership.sh`, `src/ops/*`, Phase 17 pair paths.

Assembler: wire new modules after existing `src/migration/**`; version bump only when implementation authorized (not now).

## Structured codes (minimum)

`MIGRATION_PAIR_REQUIRED`, `MIGRATION_PAIR_INVALID`, `MIGRATION_PAIR_EXPIRED`, `MIGRATION_PAIR_REVOKED`, `MIGRATION_DOMAIN_REQUIRED`, `MIGRATION_DOMAIN_INVALID`, `MIGRATION_DOMAIN_OWNERSHIP_MISMATCH`, `MIGRATION_DOMAIN_ALREADY_BOUND`, `MIGRATION_DOMAIN_STRATEGY_REQUIRED`, `MIGRATION_DNS_CHALLENGE_REQUIRED`, `MIGRATION_DNS_CHALLENGE_EXPIRED`, `MIGRATION_DNS_CHALLENGE_INVALID`, `MIGRATION_DNS_CHALLENGE_REPLAY_DENIED`, `MIGRATION_DNS_RECORD_NOT_FOUND`, `MIGRATION_DNS_RECORD_MISMATCH`, `MIGRATION_DNS_PROPAGATION_PENDING`, `MIGRATION_DNS_AUTHORITATIVE_MISMATCH`, `MIGRATION_DNSSEC_VALIDATION_FAILED`, `MIGRATION_IPV4_UNREACHABLE`, `MIGRATION_IPV6_UNREACHABLE`, `MIGRATION_LANDING_PREPARE_FAILED`, `MIGRATION_LANDING_HEALTH_FAILED`, `MIGRATION_NGINX_CONFIG_INVALID`, `MIGRATION_PORT_CONFLICT`, `MIGRATION_CAA_BLOCKED`, `MIGRATION_ACME_ORDER_FAILED`, `MIGRATION_TLS_ISSUANCE_FAILED`, `MIGRATION_TLS_CHAIN_INVALID`, `MIGRATION_TLS_HOSTNAME_MISMATCH`, `MIGRATION_TLS_KEY_STORAGE_FAILED`, `MIGRATION_ROUTING_NOT_READY`, `MIGRATION_SOURCE_ROUTING_CHANGED`, `MIGRATION_SOURCE_DISRUPTION_DETECTED`, `MIGRATION_DOMAIN_ABORTED`, `MIGRATION_RECOVERY_REQUIRED`, `MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED`, `MIGRATION_CUTOVER_NOT_AUTHORIZED`, `MIGRATION_TOKEN_NOT_CONSUMED` (assert remains unconsumed).
