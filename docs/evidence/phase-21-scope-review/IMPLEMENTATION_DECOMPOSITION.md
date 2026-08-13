# IMPLEMENTATION_DECOMPOSITION.md

Proposed modules — **do not implement** until owner authorization (OD-42).

## soviez-sh (installer)

```text
src/migration/cutover/
  codes.sh              # Phase 21 gates; replace env-flag cutover
  model.sh              # State JSON schemas
  targeting.sh          # authorization_id + pair bind
  preflight.sh          # Phase 20/21 readiness revalidation
  final_sync.sh         # Optional delta sub-op
  route_activate.sh     # nginx Production upstream
  tls_validate.sh       # Production cert gate
  dns_instruction.sh    # Manual-first instruction + attestation
  source_transition.sh  # freeze → maintenance
  health.sh             # Public health/smoke suite
  commit.sh             # traffic_owner flip
  integrations.sh       # Incremental mail/pay/webhook/cron
  stage_public.sh       # Selected Stage routing
  rollback.sh           # Rollback orchestration
  triggers.sh           # Automatic rollback evaluation
  report.sh             # Signed completion + audit
  engine.sh             # Parent operation state machine
src/migration/commands/
  cutover.sh            # CLI entrypoints
tests/
  unit/test_phase21_cutover_unit.sh
  integration/test_phase21_cutover_e2e.sh
  security/test_phase21_no_unauthorized_cutover.sh
```

## Reuse (no fork)

- `src/nginx/ownership.sh`, `src/ssl/promote.sh`, `src/ssl/challenge.sh`
- `src/migration/phase21_readiness/` → extend for post-cutover readiness
- `src/migration/routing/*` → routing plan consumption
- `src/migration/final_sync/` → cutover final sync adapter
- `src/ops/*` → locks, pause, recover
- `src/backup/inventory.sh` → pin verification

## soviez-saas (separate repo; frozen UI)

- `traffic_owner` authoritative transition RPC
- Cutover audit event types (metadata only)
- Idempotency registry entry for cutover commit
- **No** DNS mutation API; **no** traffic relay

## Soviez ERP

- `local_license_guard`: add `migration_origin_grace`, `production_licensed_pre_cutover`, `traffic_owner` recognition (OD-38)
- Until shipped: installer binding JSON + health LG probe

## Gate change (when authorized)

```bash
# Replace blanket deny with scoped allow:
soviez_migration_assert_phase21_cutover_allowed "$op_type"
# Still forbids: purge, SaaS relay, env-flag bypass, legacy change-domain
```

## CLI proposal (documentation only)

```text
soviez.sh --migration-cutover-plan <authorization-id>
soviez.sh --migration-cutover-run <authorization-id> [--step ...]
soviez.sh --migration-cutover-rollback <authorization-id>
soviez.sh --migration-cutover-status <operation-id>
```

## Sequencing for implementation PASS

1. Gates + model + preflight
2. Route + TLS (dest only)
3. DNS instruction + attestation (no live mutation in tests)
4. Source transition + health
5. Commit + ledger traffic_owner
6. Integrations + Stage public
7. Rollback + triggers
8. E2E matrix (`TEST_PLAN.md`)

## Estimated complexity

**Very High** — cross-host orchestration, irreversible traffic epoch, manual DNS coupling, rollback safety.

Proposed progress weight **1** (uncredited in this review).
