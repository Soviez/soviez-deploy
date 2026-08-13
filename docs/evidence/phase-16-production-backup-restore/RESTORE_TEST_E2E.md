# Restore-test E2E
`--backup-restore-test` / `--restore-test` materializes disposable restore of dump without Production switch.
Marks `RESTORE_TESTED` when successful.

Under `SOVIEZ_TEST_MODE`, candidate ERP startup uses fixture markers (not a full disposable Odoo `/web/login` proof).

**Gap:** real disposable ERP candidate HTTP login after restore-test not certified this pass → contributes to Phase 16 **PARTIAL**.
