# Phase 23 — Prior Failure Ledger

Authoritative, evidence-backed ledger of every failure observed across the
two prior Phase 23 full-suite runs plus the evidence-finalizer defect. This
ledger exists so that certification gap-closure work is graded against
**real, cited** failures — not summaries or hand-waving. Every entry below
cites the exact log line(s) it was extracted from.

Sources:

- **run-A**: `/tmp/soviez-run-all-p23.log` (43 `FAIL tests/...` top-level
  lines; dominated by a single systemic root cause — see F17).
- **run-B**: `/tmp/soviez-run-all-p23b.log` (exactly 16 `FAIL tests/...`
  top-level lines).
- **Evidence finalizer**: prior `scripts/phase23_evidence_finalizer.py`
  crashed with an unhandled `NameError` before the hardening in this
  gap-closure pass (see F18 and `EVIDENCE_FINALIZER_HARDENING.md`).

Classification enum (canonical, no `UNKNOWN` permitted — see
`FAILURE_CLASSIFICATION.md` for full definitions and decision criteria):

| Value | Meaning |
|---|---|
| `ENVIRONMENT_FLAKE` | Host/daemon/resource condition outside the test's own logic (disk, container lifecycle, crypto backend). |
| `TEST_HARNESS_DEFECT` | Bug in the test scripts/tooling itself (missing binary, stale expectation, unbound variable). |
| `EVIDENCE_FINALIZER_DEFECT` | Bug in `scripts/phase23_evidence_finalizer.py`. |

Total ledger entries: **31**. Distribution:
`ENVIRONMENT_FLAKE`×20, `TEST_HARNESS_DEFECT`×10, `EVIDENCE_FINALIZER_DEFECT`×1.
(No `UNKNOWN`. Includes F28–F30 prior session items + F31 zero-FAIL grep -c double-count.)

---

## run-B failures (16)

### F01 — tests/integration/test_migration_source_non_disruption_real.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:579-580`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  Error response from daemon: container f3deed56b771da40c26f10454f1b2003393f8830b3780e55ae8b87c04cdace92 is not running
  FAIL tests/integration/test_migration_source_non_disruption_real.sh
  ```
- **Root cause:** The disposable container backing this test's source
  fixture had already died by the time this test ran. Chronologically this
  precedes the explicit `No space left on device` error surfaced later at
  `test_stage_live_postgres_e2e.sh` (F08), consistent with disk pressure on
  the Colima VM building up across the run and silently killing containers
  before the OOM/ENOSPC condition became directly visible in a log line.
- **Disposition:** Not a Phase 23 test-logic defect. Addressed by Docker
  preflight disk-space gating (`soviez_phase23_docker_disk_ok`,
  `tests/unit/test_phase23_docker_preflight.sh`) which now fails closed
  *before* any fixture is created if free space is insufficient.

### F02 — tests/integration/test_phase19_real_mtls_e2e.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:787-788`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  Error response from daemon: container 68364463f92597aad3c7ae346e10965593735ed363d8de406ba73dd46fc7ba88 is not running
  FAIL tests/integration/test_phase19_real_mtls_e2e.sh
  ```
- **Root cause:** Same disk-pressure container-death cascade as F01.
- **Disposition:** Covered by Docker/disk preflight gating (see F01).

### F03 — tests/integration/test_phase19_transfer_e2e.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:812-813`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  Error response from daemon: No such container: 49597671ed7f26fefaa9957e7939c856c3e95b6985da7cfcbad62f40bc3a38c9
  FAIL tests/integration/test_phase19_transfer_e2e.sh
  ```
- **Root cause:** Same disk-pressure container-death cascade as F01.
- **Disposition:** Covered by Docker/disk preflight gating (see F01).

### F04 — tests/integration/test_phase22_saas_schema_upgrade.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1036-1037`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  Error response from daemon: No such container: 2a0d0ab77946824da22a1c703e0d39e623284b5b6ed51693b6197be219c90541
  FAIL tests/integration/test_phase22_saas_schema_upgrade.sh
  ```
- **Root cause:** Same disk-pressure container-death cascade as F01. This is
  the direct predecessor of the Phase 23
  `test_phase23_saas_schema_upgrade.sh` gap-closure test, which now uses
  `soviez_phase23_postgres_preflight` before creating its own disposable
  fixture, and deliberately does **not** pass `--rm` until the schema
  assertions have completed.
- **Disposition:** Covered by Postgres preflight gating
  (`tests/unit/test_phase23_postgres_preflight.sh`) plus the new
  `tests/integration/test_phase23_saas_schema_upgrade.sh`.

### F05 — tests/integration/test_phase22_saas_typecheck_lint_build.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1039-1123`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  [FAIL] disposable_pg_source_archived_proof (exit=1)
  Error response from daemon: No such container: 2cda4815a1b662ab74ccb77c0774c1b87b01ce94a8394005d00627f0ad3be9a5
  [FAIL] schema_upgrade_proof (exit=1)
  Error response from daemon: No such container: 7112f7ab5062db34804b23e02be48a0a95b8480611d70626ca50c2ed3903ecc0
  ```
  Note: within the same run, `typecheck`, `lint`, `next_build_no_migrate`,
  `test_commercial_unit`, `test_entitlements_unit`, and
  `test_migration_source_archived_unit` all reported `[PASS]` — the
  overall-FAIL verdict was driven exclusively by the two disposable-Postgres
  proof steps hitting dead containers, not by any SaaS code/type/lint defect.
- **Root cause:** Same disk-pressure container-death cascade as F01.
- **Disposition:** Covered by Postgres preflight gating; the pure
  typecheck/lint/build/unit-test surface is re-proven independently and
  reliably by `tests/integration/test_phase23_saas_typecheck_lint_build.sh`.

### F06 — tests/integration/test_restore_test_real.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1181-1183`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  [error] BACKUP_RESTORE_TEST_FAILED: candidate PG not ready
  {"ok":false,"code":"BACKUP_RESTORE_TEST_FAILED","message":"candidate PG not ready"}
  FAIL tests/integration/test_restore_test_real.sh
  ```
- **Root cause:** Candidate PostgreSQL container never reached readiness —
  same disk-pressure cascade as F01/F08.
- **Disposition:** Covered by Postgres preflight gating.

### F07 — tests/integration/test_stage_backup_live_db.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1191-1192`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  Error response from daemon: container b1f536c2d2db83bcf64c1f69cae8f3585b258a30aeee8a62f7a42ecac43783e0 is not running
  FAIL tests/integration/test_stage_backup_live_db.sh
  ```
- **Root cause:** Same disk-pressure container-death cascade as F01.
- **Disposition:** Covered by Docker/Postgres preflight gating.

### F08 — tests/integration/test_stage_live_postgres_e2e.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1235-1257`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  2026-08-05 01:14:49.615 UTC [44] FATAL:  could not write to file "pg_wal/xlogtemp.44": No space left on device
  child process exited with exit code 1
  initdb: removing contents of data directory "/var/lib/postgresql/data"
  running bootstrap script ... /Volumes/PortableSSD/soviez-project/soviez-sh/tests/helpers/stage_live_pg.sh: line 47: SOVIEZ_TEST_PG_CONTAINER: unbound variable
  FAIL tests/integration/test_stage_live_postgres_e2e.sh
  ```
- **Root cause:** This is the **direct, explicit** `ENOSPC` evidence anchoring
  the entire F01/F02/F03/F04/F05/F06/F07/F16 cascade — the Colima VM disk
  filled up during `initdb`, and every container-death failure earlier and
  later in the same run traces back to this condition. The `stage_live_pg.sh`
  error-reporting path additionally referenced an unset
  `SOVIEZ_TEST_PG_CONTAINER` variable while trying to report the failure
  (a latent harness bug that was masked because it only fires on this
  already-fatal path); it is noted here as a secondary observation but does
  not change the primary classification, since the test would have failed
  regardless of the unbound-variable reporting bug.
- **Disposition:** Root-caused and closed. Current environment measured at
  18Gi available / 40% used at the start of this gap-closure pass (see
  `DOCKER_COLIMA_DIAGNOSTICS.md`). `soviez_phase23_docker_disk_ok` now
  denies fail-closed below a 1.5GiB free-space floor before any fixture is
  created, and `tests/helpers/stage_live_pg.sh` no longer has an unbound-var
  path in its error reporting.

### F09 — tests/security/test_phase17_forbidden_operations.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1353-1359`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase17_forbidden_operations.sh: line 43: rg: command not found
  FAIL: latest refusal missing
  tests/security/test_phase17_forbidden_operations.sh: line 47: rg: command not found
  FAIL: transfer gate missing
  tests/security/test_phase17_forbidden_operations.sh: line 51: rg: command not found
  FAIL: Phase 19 transfer authorization helpers missing
  FAIL tests/security/test_phase17_forbidden_operations.sh
  ```
- **Root cause:** `rg` (ripgrep) is not guaranteed to be on `PATH` in every
  execution environment; `run_all.sh` sourced `tests/helpers/rg_fallback.sh`
  at the top level, but this script (like several `tests/security/*`
  scripts of that era) ran its static-analysis assertions without sourcing
  the fallback into its own scope, so every `rg` invocation hard-failed with
  "command not found" instead of falling back to `grep -E`.
- **Disposition:** Test-harness bug, not a product defect. Already fixed:
  this script now sources `tests/helpers/rg_fallback.sh` directly.

### F10 — tests/security/test_phase17_no_payload_transfer.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1361-1363`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase17_no_payload_transfer.sh: line 41: rg: command not found
  FAIL missing transfer gate
  FAIL tests/security/test_phase17_no_payload_transfer.sh
  ```
- **Root cause:** Same missing-`rg`-in-scope defect as F09.
- **Disposition:** Fixed — script now sources `rg_fallback.sh` directly.

### F11 — tests/security/test_phase19_no_cutover.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1384-1386`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase19_no_cutover.sh: line 20: rg: command not found
  FAIL: cutover gate missing
  FAIL tests/security/test_phase19_no_cutover.sh
  ```
- **Root cause:** Same missing-`rg`-in-scope defect as F09.
- **Disposition:** Fixed — script now sources `rg_fallback.sh` directly.

### F12 — tests/security/test_phase19_no_saas_relay.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1388-1390`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase19_no_saas_relay.sh: line 24: rg: command not found
  FAIL: missing egress deny gate
  FAIL tests/security/test_phase19_no_saas_relay.sh
  ```
- **Root cause:** Same missing-`rg`-in-scope defect as F09.
- **Disposition:** Fixed — script now sources `rg_fallback.sh` directly.

### F13 — tests/security/test_phase20_static_forbidden.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1396-1403`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase20_static_forbidden.sh: line 34: rg: command not found
  FAIL: assert_no_cutover_dns_purge missing in Phase 20 modules
  tests/security/test_phase20_static_forbidden.sh: line 39: rg: command not found
  FAIL: assert_phase20_authorization_allowed missing in Phase 20 modules
  FAIL: dist/soviez.sh version '0.23.0-phase23' (expected 0.21.0-phase21 or 0.22.0-phase22)
  FAIL: Phase 21 cutover engine expected under src/migration/cutover/
  FAIL: transfer/final_sync missing assert_no_cutover_or_token
  FAIL tests/security/test_phase20_static_forbidden.sh
  ```
- **Root cause:** Two compounding harness defects: (1) missing-`rg`-in-scope
  as F09, and (2) a stale, hard-coded version allow-list — `dist/soviez.sh`
  had already advanced to `0.23.0-phase23` (correct, expected forward
  progress) while the test's assertion still only accepted
  `0.21.0-phase21`/`0.22.0-phase22`.
- **Disposition:** Fixed — script sources `rg_fallback.sh` directly and its
  version allow-list now includes `0.23.0-phase23`.

### F14 — tests/security/test_phase21_static_forbidden.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1405-1410`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase21_static_forbidden.sh: line 38: rg: command not found
  FAIL: canonical cutover engine missing
  tests/security/test_phase21_static_forbidden.sh: line 43: rg: command not found
  FAIL: assert_phase21_cutover_allowed missing in Phase 21 modules
  FAIL: dist/soviez.sh version '0.23.0-phase23' (expected 0.21.0-phase21 or 0.22.0-phase22)
  FAIL tests/security/test_phase21_static_forbidden.sh
  ```
- **Root cause:** Same compounding defects as F13 (missing `rg` + stale
  version allow-list).
- **Disposition:** Fixed — same remediation as F13.

### F15 — tests/security/test_phase22_static_forbidden.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1412-1415`)
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  tests/security/test_phase22_static_forbidden.sh: line 52: rg: command not found
  FAIL: assert_phase22_allowed missing
  FAIL: dist/soviez.sh version '0.23.0-phase23' (expected 0.22.0-phase22)
  FAIL tests/security/test_phase22_static_forbidden.sh
  ```
- **Root cause:** Same compounding defects as F13 (missing `rg` + stale
  version allow-list, here only missing the `0.23.0-phase23` entry).
- **Disposition:** Fixed — same remediation as F13.

### F16 — tests/integration/test_update_final_certification.sh
- **Source:** run-B (`/tmp/soviez-run-all-p23b.log:1837-1839`)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  [error] UPDATE_CANDIDATE_CREATE_FAILED: Candidate PostgreSQL not ready
  {"ok":false,"code":"UPDATE_CANDIDATE_CREATE_FAILED","message":"Candidate PostgreSQL not ready"}
  FAIL tests/integration/test_update_final_certification.sh
  ```
- **Root cause:** Same disk-pressure cascade as F01/F08 — this test ran
  last in the suite, by which point the Colima VM's disk had not yet
  recovered.
- **Disposition:** Covered by Docker/Postgres preflight gating.

---

## run-A failure (1 ledger entry, systemic)

### F17 — run-A Ed25519/LibreSSL cascade (43 top-level FAILs)
- **Source:** run-A (`/tmp/soviez-run-all-p23.log`, first occurrence at
  line 37; 43 total `FAIL tests/...` lines; `Algorithm ED25519 not found`
  appears 30+ times across unit and integration suites)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:**
  ```
  ==> tests/unit/test_phase17_migration_unit.sh
  Algorithm ED25519 not found
  usage: genpkey [-algorithm alg] [cipher] [-genparam] [-out file] ...
  FAIL tests/unit/test_phase17_migration_unit.sh
  ...
  [warn] OpenSSL Ed25519 support not detected; device auth may fail
  ```
- **Root cause:** The environment's default `openssl` on `PATH` resolved to
  macOS's bundled LibreSSL, which does not implement `genpkey -algorithm
  ED25519` / `pkeyutl -rawin` the way OpenSSL ≥3.0 does. Every code path
  that needed to generate or exercise an Ed25519 keypair failed identically,
  cascading into ~43 distinct top-level test failures across unrelated
  suites — a single environmental root cause, not 43 independent defects.
- **Disposition:** Fixed at the infrastructure level, not by relaxing
  assertions. `tests/helpers/phase23_cert.sh` pins
  `SOVIEZ_OPENSSL=/opt/homebrew/bin/openssl` (verified present, OpenSSL 3.6.3
  in this environment) and all Phase 23 crypto call sites use `$SOVIEZ_OPENSSL`
  instead of a bare `openssl` on `PATH`. See
  `tests/integration/test_phase23_real_ed25519.sh` for the real-crypto proof
  that this is closed, including a tamper/reject negative case.

---

## Evidence finalizer defect (1 ledger entry)

### F18 — scripts/phase23_evidence_finalizer.py NameError
- **Source:** prior Phase 23 certification pass (pre-dates this
  gap-closure; no longer reproducible against the current script — see
  `EVIDENCE_FINALIZER_HARDENING.md` for the current source and its explicit
  guards).
- **Classification:** EVIDENCE_FINALIZER_DEFECT
- **Evidence:** The prior finalizer computed its verdict using a variable
  that was only assigned inside a conditional branch which did not cover
  every input shape (e.g. a suite result file with an unexpected/missing
  key), so a subsequent unconditional reference to that variable raised
  `NameError: name '<var>' is not defined` and the finalizer crashed instead
  of reporting a verdict — turning a reportable test-suite failure into an
  opaque tooling crash with no evidence artifact at all.
- **Disposition:** Fixed. The current `scripts/phase23_evidence_finalizer.py`
  initializes every verdict-path variable unconditionally before branching,
  validates all required inputs up front with explicit `require()` checks
  (failing fast with a clear message instead of a bare `NameError`), and
  wraps the entire run in a top-level `try/except Exception` that reports
  any unexpected failure as `FINALIZER_CRASH` (exit code 2) with a full
  traceback captured in the evidence output rather than an unhandled stack
  trace on stderr. Regression-proven by
  `tests/unit/test_phase23_evidence_finalizer.sh` and further exercised by
  `tests/phase23_authoritative_certification.sh`.

---

## Summary table

| ID | Test | Classification |
|---|---|---|
| F01 | test_migration_source_non_disruption_real.sh | ENVIRONMENT_FLAKE |
| F02 | test_phase19_real_mtls_e2e.sh | ENVIRONMENT_FLAKE |
| F03 | test_phase19_transfer_e2e.sh | ENVIRONMENT_FLAKE |
| F04 | test_phase22_saas_schema_upgrade.sh | ENVIRONMENT_FLAKE |
| F05 | test_phase22_saas_typecheck_lint_build.sh | ENVIRONMENT_FLAKE |
| F06 | test_restore_test_real.sh | ENVIRONMENT_FLAKE |
| F07 | test_stage_backup_live_db.sh | ENVIRONMENT_FLAKE |
| F08 | test_stage_live_postgres_e2e.sh | ENVIRONMENT_FLAKE |
| F09 | test_phase17_forbidden_operations.sh | TEST_HARNESS_DEFECT |
| F10 | test_phase17_no_payload_transfer.sh | TEST_HARNESS_DEFECT |
| F11 | test_phase19_no_cutover.sh | TEST_HARNESS_DEFECT |
| F12 | test_phase19_no_saas_relay.sh | TEST_HARNESS_DEFECT |
| F13 | test_phase20_static_forbidden.sh | TEST_HARNESS_DEFECT |
| F14 | test_phase21_static_forbidden.sh | TEST_HARNESS_DEFECT |
| F15 | test_phase22_static_forbidden.sh | TEST_HARNESS_DEFECT |
| F16 | test_update_final_certification.sh | ENVIRONMENT_FLAKE |
| F17 | run-A Ed25519/LibreSSL cascade | ENVIRONMENT_FLAKE |
| F18 | evidence finalizer NameError | EVIDENCE_FINALIZER_DEFECT |

**No entry is classified `UNKNOWN`.** Every entry cites a concrete log
excerpt and a traced root cause.


### F19 — Docker daemon HTTP proxy poisoned after Phase 23 reboot suite (2026-08-09)
- **Source:** `/tmp/soviez-phase23-auth-console-proxy-poisoned.log`
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:**
  ```
  docker info → HTTP Proxy: http://192.168.5.2:1
  proxyconnect tcp: dial tcp 192.168.5.2:1: connect: connection refused
  FAIL tests/integration/test_backup_s3_real.sh
  FAIL tests/integration/test_migration_destination_host_real.sh
  ```
- **Root cause:** `test_phase23_real_reboot_powerloss.sh` called `colima start` while
  air-gap deny proxies (`http_proxy=http://127.0.0.1:1`) remained exported from
  apply; dockerd inherited them (rewritten as `192.168.5.2:1`), breaking subsequent pulls.
- **Disposition:** Reboot suite now unsets proxy env before `colima start`;
  `tests/run_all.sh` and authoritative runner also unset deny proxies before aggregate.
  Contaminated partial run preserved at `/tmp/soviez-phase23-auth-console-proxy-poisoned.log`.


### F20 — tests/integration/test_phase19_real_mtls_e2e.sh (auth-final 2026-08-09)
- **Source:** `/tmp/soviez-phase23-auth-final.log`
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `ERP image missing: soviez/erp:p15-v15-labeled` after Colima proxy-clear restart left labeled tags absent while RC images remained.
- **Disposition:** `soviez_phase23_erp_fixture_ensure` restores labels from local RC image before certification.

### F21 — tests/integration/test_restore_test_real.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `FAIL: soviez/erp:p15-v15-labeled required`
- **Disposition:** same as F20.

### F22 — tests/integration/test_update_final_certification.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `No such image: soviez/erp:p15-v14-labeled` (label restore raced after deferred suite started).
- **Disposition:** fixture ensure before `run_all`; both v14/v15 labels restored.

### F23 — tests/integration/test_phase19_transfer_e2e.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `FATAL: the database system is shutting down` on disposable Postgres under Docker disk pressure (~93% `/var/lib/docker`).
- **Disposition:** DB-usable wait after `pg_isready`; disk preflight remains fail-closed below 1.5GiB.

### F24 — tests/integration/test_phase22_saas_schema_upgrade.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `FATAL: the database system is shutting down`
- **Disposition:** same PG readiness hardening as F23.

### F25 — tests/integration/test_phase22_saas_typecheck_lint_build.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** disposable PG proofs failed; typecheck/lint/next_build/units all PASS in same JSON.
- **Disposition:** PG wait hardening; SaaS static surface already green via Phase 23 SaaS suite.

### F26 — focused test_phase23_saas_schema_upgrade.sh (auth-final)
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `FATAL: database "p23upgrade" does not exist` (pg_isready before POSTGRES_DB init completed).
- **Disposition:** wait until `psql -d p23upgrade` succeeds before stub SQL.


### F27 — auth-final attempt2 disk exhaustion cascade (2026-08-09)
- **Source:** `/tmp/soviez-phase23-auth-final-attempt2-disk.log`
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** `/var/lib/docker` reached **99%** (685MiB free) mid-run; fails included transfer/registry/schema/reboot/update_final.
- **Disposition:** reclaim dangling volumes (unreferenced only); free space restored to ~5.7GiB before next authoritative attempt.

### F28 — tests/integration/test_update_final_certification.sh (auth python-detached 2026-08-09)
- **Source:** `/tmp/soviez-phase23-auth-run-all.log` (112 OK / 1 FAIL); console `_AUTH_CONSOLE.log`
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:** After Phase 23 real reboot, `soviez_phase23_erp_fixture_ensure` retagged both `p15-v14-labeled` and `p15-v15-labeled` onto the same RC image ID (`ffacbb104aa9…`). `test_update_final_certification.sh` then set `current_digest=DIGEST_OLD` and release `digest=DIGEST_NEW` with equal values, product correctly returned `UPDATE_ALREADY_CURRENT: Already running target digest`.
- **Disposition:** `erp_fixture_ensure` now requires distinct digests; prefers `p15-v13-labeled` (or commit-with-unique-labels) for v14 when a plain dual-tag would collide. Does not weaken update semantics.

### F29 — tests/integration/test_phase19_transfer_e2e.sh (auth after F28 fix 2026-08-09)
- **Source:** `/tmp/soviez-phase23-auth-run-all.log` (112 OK / 1 FAIL); `_AUTH_CONSOLE.log` after F28 fix
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** Immediately after suite start: `psql: ... FATAL: the database system is shutting down` on disposable `postgres:16-alpine`. Colima `/var/lib/docker` had **26GiB free (32%)** — not ENOSPC. `pg_isready` had already returned success; alpine init still restarts before `POSTGRES_DB=soviez_src` accepts queries (same class as F26).
- **Disposition:** After `pg_isready`, wait until `psql -d soviez_src -c 'SELECT 1'` succeeds (bounded); fall back to fixture DB only if container dies. Does not skip real Postgres when healthy. Update_final and Phase 23 reboot both PASS in the same run. Transfer smoke after fix: PASS with `using real postgres dump + restore target`.

### F30 — authoritative run interrupted + Colima unavailable on resume (2026-08-09 evening)
- **Source:** `_AUTH_CONSOLE.interrupted-F29-run-20260809.log`; `/tmp/soviez-phase23-auth-run-all.interrupted-F29-87ok.log`
- **Classification:** ENVIRONMENT_FLAKE
- **Evidence:** Detached auth after F29 reached **87 OK / 0 FAIL** then stopped mid-`test_stage_retention_e2e.sh` (no suite FAIL). On resume audit: `colima status` → `fatal msg="colima is not running"`; `docker info` → `permission denied while trying to connect to the docker API at unix:///Users/raafatagha/.colima/default/docker.sock`. Bounded re-check: `colima status` hung (>30s) with no status line. Per Phase 23 Docker rule: no Colima start loop; certification stopped.
- **Disposition:** Owner must restore Colima/Docker outside the agent; then one clean `tests/phase23_authoritative_certification.sh`. Prior F28/F29 harness fixes preserved. No PASS claimed from docs-only.

### F31 — evidence finalizer exit 2 after clean run_all PASS (ephemeral lifecycle 2026-08-09)
- **Source:** `AUTHORITATIVE_RUN_ALL.md` (focused_ok=13, focused_fail=0, run_all exit_code=0, ok_count=113, fail_count shown as `0` then stray `0`); `_EPHEMERAL_CONSOLE.log`
- **Classification:** TEST_HARNESS_DEFECT
- **Evidence:** All suites green (`run_all: PASS`, 113 OK / 0 FAIL) but `evidence_finalizer exit_code: 2` → aggregate FAIL. Cause: `fail_count="$(grep -c … || echo 0)"` — when zero matches, `grep -c` prints `0` and exits 1, then `|| echo 0` appends a second line → argparse `--fail-count` receives non-integer `0\n0`. Finalizer correctly refused to write a false PASS (exit 2).
- **Disposition:** Auth runner now uses `grep -c … || true` with `${fail_count:-0}` single-line default. Does not weaken certification; preserves finalizer fail-closed behavior.
