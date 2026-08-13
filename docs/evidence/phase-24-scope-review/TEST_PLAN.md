# TEST_PLAN.md — Phase 24 (implementation-ready)

## A. Baseline and readiness
1. Phase 23 PASS baseline (installer/SHA pinned).
2. `--offline-phase24-readiness` remains non-authorizing (WARNING or enriched).
3. Expired/drifted readiness (if TTL implemented) → BLOCKED codes.
4. Wrong artifact / wrong SHA / wrong version → fail closed.
5. Active conflicting operation → `SECURITY_CONFLICT`.
6. Unresolved recovery on optional hygiene migrate → `SECURITY_RECOVERY_REQUIRED`.

## B. Unsigned self-update / signed enforcement
1. Static: no `update_self` / `ensure_local_soviez_sh` in `src`/`dist`.
2. Production path: soft STRICT_SIG cannot ignore verify failure.
3. Fixture token default denied outside TEST_MODE.
4. Fake/fixture signatures denied outside TEST_MODE / cert flags.
5. Migration unsigned offline flag denied outside TEST_MODE.
6. Doc assertion: privacy doc does not advertise optional self-update.

## C. Key hygiene
1. Activation secret files mode 0600 preserved.
2. Per OD: hashing/envelope behavior verified.
3. No secrets in argv/logs (`tests/security` redaction).
4. Multi-tenant: License A secrets invisible to License B paths.

## D. Ticket replay matrix
1. Stage offline jti consume-once.
2. Offline bundle second apply denied.
3. Update offline nonce replay denied.
4. Migration offline package replay denied.
5. DNS challenge replay denied.
6. Cross-suite: no second successful independent consume.

## E. Registry lockdown
1. Temp DOCKER_CONFIG created and removed.
2. Logout/cleanup after pull/export.
3. Bundle secret scan: no auths/passwords/keys.
4. Residual HOME docker auth → lockdown failure (per policy).
5. No permanent login instructions in operator docs.

## F. Secret-scan CI + local
1. CI workflow exists and fails on planted secret fixture in PR simulation.
2. Local `security-scan` / suite finds `BEGIN PRIVATE KEY` / service-role credential patterns in dist.
3. Deny-list-only `service_role` string does not false-fail if OD clarifies.

## G. Sovereignty / egress regression
1. No phone-home in security commands.
2. Static forbidden: SaaS relay, business dump upload.
3. Backup/restore/status still work offline.

## H. Multi-tenant
Use ≥2 Licenses/environments for secret isolation and exact-target denial.

## I. Reboot/recovery
Only for optional `security_key_hygiene_migrate` / durable ops — Colima stop/start once; no duplicate mutate.

## J. Integration
Disposable Registry/Postgres only where lockdown/replay needs real Docker. Prefer static for CI-cost items.

## K. Aggregate
`tests/run_all.sh` PASS + Phase 24 focused suite PASS + CI green.

## PASS / WARNING / BLOCKED (implementation cert)
- **PASS:** all material suites green; CI green; no unsigned path; acceptance met.
- **WARNING:** optional hygiene deferred by OD with compensating controls documented.
- **BLOCKED:** any BLOCKING_PHASE24 debt open; CI missing; soft-sig remains default; secrets in dist.
