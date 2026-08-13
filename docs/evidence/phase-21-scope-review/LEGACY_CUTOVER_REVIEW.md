# LEGACY_CUTOVER_REVIEW.md

## Scope

Review of legacy cutover-adjacent paths that must **not** drive Phase 21.

## Legacy `--change-domain` / `--formssl` (`soviez-deploy/soviez.sh`)

| Aspect | Legacy behavior | Phase 21 stance |
|--------|-----------------|-----------------|
| DNS | Assumes operator already changed DNS | **O** — no pair binding, no grace epoch |
| SSL | Certbot on host, repoints nginx | **O** — bypasses ownership markers and rollback window |
| Maintenance | May stop ERP containers | **U** — conflicts with migration state machine |
| Authorization | No Migration Token / grace / traffic_owner | **U** — commercial and split-brain unsafe |
| Rollback | Ad hoc | **U** — no signed operation ledger |

**Recommendation:** Document as historical reference only. Phase 21 cutover MUST use migration operation engine bound to authorization_id.

## Dashboard wallet migrate (`migrate_license_ip`)

| Aspect | Legacy | Phase 21 stance |
|--------|--------|-----------------|
| Trigger | Browser cookie/OTP | **O** for installer migration path |
| Scope | IP/fingerprint rebind only | **O** — no cutover orchestration |
| Idempotency | Session resume, not operation_id | **U** |

Phase 20 ledger path is authoritative. Phase 21 does not reintroduce dashboard migrate as cutover entry.

## Env-flag "enable cutover" pattern

```text
SOVIEZ_MIG_ALLOW_CUTOVER=1
SOVIEZ_MIG_DNS_CUTOVER=1
```

Present in codebase as **hard deny** targets. Phase 21 must not ship production cutover behind env flags. Cutover requires:

1. Valid Phase 21 readiness (PASS/WARNING per policy).
2. Explicit operation authorization in operation engine.
3. Owner-approved runbook step — not ambient env.

Classification: **U** if used as production gate; **R** only as test harness with documented isolation.

## Fixture-only DNS provider

Phase 18 tests use filesystem/mock DNS adapters. Live Production cutover requires:

- Manual DNS instruction as **first-class** path (default).
- Optional provider adapters (Route53, Cloudflare, etc.) as **local** mock/live modules — never SaaS relay.

Classification: fixture adapter **U** for Production; manual path **R**.

## `migration_pre_cutover_reversal` stub

Op type registered in `authorization/codes.sh` but engine unimplemented. Phase 21 scope:

- **Exclude** from cutover happy path.
- **Include** in exceptional rollback-before-traffic_owner documentation.
- Implement only if owner closes OD-23/OD-24 analogs for Phase 21.

Classification: **G** / **U** if invoked without implementation.

## `soviez_update_switch` "container cutover"

Version switch for update engine — unrelated to migration traffic ownership. Do not conflate in docs or CLI.

Classification: **D**.

## Summary

| Legacy primitive | Verdict |
|------------------|---------|
| `--change-domain` | **Obsolete — forbidden** |
| `--formssl` standalone | **Obsolete — forbidden** |
| Dashboard migrate wizard | **Obsolete for migration cutover** |
| Env cutover flags | **Unsafe for Production** |
| Fixture DNS only | **Unsafe for live Production** |
| Pre-cutover reversal stub | **Gap — do not call** |

Phase 21 cutover = migration operation engine + Phase 17–20 artifacts + Phase 12 nginx/SSL + manual DNS first.
