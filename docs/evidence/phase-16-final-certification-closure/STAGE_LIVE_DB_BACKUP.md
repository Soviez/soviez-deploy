# Stage live-DB backup
- Real postgres:16 disposable container + pg_dump -Fc
- Shared primitive soviez_backup_stage_live_backup
- Archive contains PGDMP magic; Stage not misclassified as Production
- Test: `tests/integration/test_stage_backup_live_db.sh` PASS
