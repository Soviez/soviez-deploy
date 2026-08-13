# EVIDENCE_FINALIZER_HARDENING

Tool: `scripts/phase23_evidence_finalizer.py`

## Defect (prior)
Python formatting/`NameError` while writing evidence after a failed authoritative run.
Classified: **EVIDENCE_FINALIZER_DEFECT** (ledger F18).

## Corrections
- Explicit argparse; all required fields validated before write
- SHA256 computed from artifact bytes; must match `^[0-9a-f]{64}$`
- Atomic write: temp file in evidence dir + `os.replace`
- Validation failure (exit 2) does **not** overwrite prior reports
- Verdict cannot be PASS if `run_all_exit`, `auth_exit`, or `fail_count` nonzero
- Separate exit codes: 0=PASS aggregate, 1=PARTIAL/FAIL written, 2=validation only

## Tests
`tests/unit/test_phase23_evidence_finalizer.sh` covers missing artifact, zero tests, PASS path, nonzero refuse PASS, empty version, duplicate finalization.
