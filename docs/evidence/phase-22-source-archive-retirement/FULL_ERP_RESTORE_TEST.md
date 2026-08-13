# FULL_ERP_RESTORE_TEST

**Status:** WARNING / skipped

- Policy flag: `SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE=1` (exported by `tests/helpers/phase22_fixture.sh`)
- Implementation returns `full_erp_restore_test=SKIPPED` / `policy=optional` when set
- Compensating proofs: **DATABASE_RESTORE_TEST PASS** (real PG) + **FILESTORE_VERIFICATION PASS**
- Full ERP stack restore remains optional extension for lab hosts with complete ERP runtime
