# EVIDENCE_ATOMIC_WRITE_PROOF

Mechanism in `atomic_write()`:
1. `mkstemp` beside target (`.<name>.XXXX.tmp`)
2. write + flush + fsync
3. `os.replace(tmp, path)` (atomic on same filesystem)
4. on failure: unlink temp; leave prior target untouched

Proven by unit suite:
- validation failure with prior `FINAL_REPORT.md` content preserved (`PRIOR_REPORT`)
- successful PASS rewrite only after validation
- PARTIAL rewrite when run_all nonzero (never false PASS)
