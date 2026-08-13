# CHANGED FILES

## Created (runtime)

- `src/migration/domain/{codes,model,targeting,strategy,source_inspection,plan,report,engine}.sh`
- `src/migration/dns/{signing,replay,authoritative,public_resolvers,provider,challenge,retry,instructions}.sh`
- `src/migration/landing/{content,headers,nginx,health,cleanup}.sh`
- `src/migration/tls/{policy,storage,verify,acme,pebble,engine}.sh`
- `src/migration/routing/{source_guard,destination_plan,drift,readiness,abort}.sh`
- Phase 18 CLI handlers in `src/migration/commands/cli.sh`
- `tests/unit/test_phase18_migration_domain_unit.sh`
- `tests/security/test_phase18_no_source_mutation.sh`
- `tests/security/test_phase18_no_payload_transfer.sh`
- `tests/integration/test_phase18_domain_dns_landing_tls_e2e.sh`
- `tests/integration/test_phase18_multi_tenant_isolation.sh`
- `tests/integration/test_phase18_reboot_matrix.sh`

## Modified

- `VERSION` → `0.18.0-phase18`
- `build/assemble.sh` (assemble new modules)
- `src/cli/parse.sh` (Phase 18 flags)
- Docs under `docs/ai`, `docs/dev`, `docs/user`, `PROJECT_STATE.md`, constitutions/contracts

## Regenerated

- `dist/soviez.sh` (+ `.sha256`)
