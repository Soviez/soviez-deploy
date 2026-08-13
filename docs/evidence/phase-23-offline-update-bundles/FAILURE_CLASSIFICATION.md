# Phase 23 — Failure Classification Standard

Every failure observed anywhere in Phase 23 certification evidence — prior
runs (`PRIOR_FAILURE_LEDGER.md`) and any future run — MUST be attributed to
exactly one of the following three categories. **`UNKNOWN` is not a
permitted value.** If a failure cannot immediately be attributed, the
investigation is not finished; do not write evidence until the true root
cause has been traced with a concrete log citation.

This file is the source of truth for the enum; enforcement is automated by
`tests/unit/test_phase23_failure_classification.sh`, which greps every
`PRIOR_FAILURE_LEDGER.md` entry and rejects the ledger if any classification
token is not one of the three below, or if `UNKNOWN`/`unclassified` appears
anywhere in the classification evidence set.

## ENVIRONMENT_FLAKE

**Definition:** The test's own logic and assertions are correct. The
failure was caused by a transient condition of the host, the container
runtime (Docker/Colima), a system dependency (e.g. the OpenSSL build
resolved on `PATH`), or a shared, mutable resource (disk space, a
long-lived disposable container) — not by a defect in the test code or the
product code under test.

**Decision criteria (must satisfy ALL):**
1. There is a concrete, quoted log line showing an infrastructure-level
   error (e.g. `No space left on device`, `container ... is not running`,
   `Algorithm ED25519 not found`, `pg_isready` timeout) — not just a test
   assertion failing.
2. The same test, run again against a healthy environment (verified disk
   space, reachable daemon, correct crypto backend), is expected to pass
   without any code change to the test or the product.
3. The condition is traceable to a specific, nameable cause (not "it just
   failed") — e.g. ENOSPC on the Colima VM, LibreSSL vs OpenSSL 3.x Ed25519
   support, a disposable container that outlived the step depending on it.

**Phase 23 gap-closure mitigations:** `soviez_phase23_docker_preflight` /
`soviez_phase23_docker_disk_ok` (fail closed below a free-space floor before
any fixture is created), `soviez_phase23_postgres_preflight` (deterministic
readiness wait with bounded retries), and pinning
`SOVIEZ_OPENSSL=/opt/homebrew/bin/openssl` for all Ed25519 operations.

**Ledger examples:** F01–F08, F16 (disk-pressure container-death cascade,
anchored by the explicit ENOSPC line in F08), F17 (Ed25519/LibreSSL
cascade).

## TEST_HARNESS_DEFECT

**Definition:** The product code under test is correct (or at least, the
failure says nothing about it) — the bug is in the test script, test
helper, or CI/tooling scaffolding itself.

**Decision criteria (must satisfy ALL):**
1. The failure message originates from the shell/test harness, not from
   product code (`soviez.sh` / `dist/soviez.sh` / `src/**`) — e.g. `command
   not found`, an unbound-variable error from `set -u`, or a hard-coded
   expectation (like a version string) that is stale relative to current,
   correct product state.
2. Fixing the test script (not the product) resolves the failure with no
   behavioral change to the system under test.
3. The defect is specific to test infrastructure: missing tool availability
   in the execution scope, a stale assumption baked into an assertion, or
   a bash-compatibility bug (e.g. `set -u` tripping on a variable that is
   only conditionally assigned).

**Phase 23 gap-closure mitigations:** every `tests/security/*` script that
uses `rg` now sources `tests/helpers/rg_fallback.sh` directly instead of
relying on it being sourced by a caller; version allow-lists in
`test_phase20_static_forbidden.sh` / `test_phase21_static_forbidden.sh` /
`test_phase22_static_forbidden.sh` include `0.23.0-phase23`.

**Ledger examples:** F09–F15 (`rg: command not found` because
`rg_fallback.sh` was not sourced in-scope; stale version allow-lists).

## EVIDENCE_FINALIZER_DEFECT

**Definition:** The failure originates in
`scripts/phase23_evidence_finalizer.py` itself — the tool responsible for
aggregating suite results and writing the final verdict/evidence artifact —
rather than in any test or the product under test.

**Decision criteria (must satisfy ALL):**
1. The traceback or crash originates in `phase23_evidence_finalizer.py`
   (not in a test script it is summarizing).
2. The underlying test results it was trying to summarize are
   available/valid; the finalizer failed to process or report them
   correctly.
3. The fix is scoped entirely to the finalizer's own code (input
   validation, atomic-write logic, verdict computation) with no change to
   test or product behavior required.

**Phase 23 gap-closure mitigations:** see `EVIDENCE_FINALIZER_HARDENING.md`
for the specific hardening applied (unconditional variable initialization,
explicit `require()` input validation, top-level `try/except` reporting
`FINALIZER_CRASH` instead of crashing bare, atomic writes — see
`EVIDENCE_ATOMIC_WRITE_PROOF.md`).

**Ledger examples:** F18 (`NameError` on a verdict variable that was only
assigned inside one conditional branch).

## Why there is no `UNKNOWN` category

Allowing an `UNKNOWN` bucket would let unresolved failures accumulate
without root-causing, which defeats the purpose of a certification gap
closure. Every failure in `PRIOR_FAILURE_LEDGER.md` was traced to a
specific log line and a specific, nameable mechanism before being recorded.
If a future failure genuinely resists classification, the correct action is
to keep investigating (add logging, reproduce in isolation, bisect) until
one of the three categories above applies — not to weaken the taxonomy.
