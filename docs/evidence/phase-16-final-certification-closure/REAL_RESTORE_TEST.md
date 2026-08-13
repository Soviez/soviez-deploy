# Real restore-test
- Flag: SOVIEZ_BACKUP_RESTORE_TEST_REAL=1
- Real encrypted Phase 16 full backup → decrypt → PG restore / fixture-init → ERP candidate
- Marks RESTORE_TESTED only on success; failures preserve VERIFIED
- Test: `tests/integration/test_restore_test_real.sh` PASS
