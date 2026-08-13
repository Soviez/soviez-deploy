# Backup / Restore Architecture

- Backup: `src/backup/`
- Restore: `src/restore/`
- S5 posture: `LOCAL_ONLY` ⇒ `dr_capable=false` (`backup_safety/posture.sh`)
- Untrusted restore: `soviez_q_restore_enter` + block switch until promoted (`quarantine/restore.sh`, `restore/switch.sh`)
