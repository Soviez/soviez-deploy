# Changed files (Phase 16 summary)
## Source
- `src/backup/*.sh` (new modular backup product)
- `src/restore/*.sh` (new modular restore product)
- `src/commands/backup.sh`, `src/commands/restore.sh`
- `src/cli/parse.sh` (CLI flags)
- `src/stage/lifecycle.sh` (calls `soviez_backup_stage_live_backup`)
- `build/assemble.sh` → `dist/soviez.sh` **0.16.0-phase16**
## Tests
- `tests/unit/test_backup_restore_unit.sh`
- `tests/integration/test_backup_restore_e2e.sh`
## Docs / evidence
- `docs/ai/PRODUCTION_BACKUP_AND_RESTORE_MODEL.md` + state/constitution updates
- `docs/dev/BACKUP_*`, `PRODUCTION_RESTORE_*`, `RESTORE_CANDIDATE_*`
- `docs/user/BACKUP_*`, `RESTORE_AND_RECOVERY.md`
- `docs/evidence/phase-16-production-backup-restore/*`
