# AUTHORITATIVE_RUN_ALL.md

```bash
bash tests/run_all.sh
```

**Result:** `run_all: PASS`  
**Exit code:** `0`  
**Log:** `/tmp/p19-auth-run-all-CLEAN.log`  
**OK count:** 73  
**FAIL count:** 0  

Includes: Phase 14–19 suites, Phase 16 S3 + SFTP, host reboot matrices (Colima), Phase 19 real mTLS/freeze/network/failure/adversary, security static gates, `test_update_final_certification.sh` (deferred last).

Prior failed monolithic attempts preserved in `CLEAN_RUN_HISTORY.md` (not rewritten).
