# Backup Security (S5)

Integrity, encryption posture, secret-leakage scan, retention helpers, disk preflight. Destination classification: `LOCAL_ONLY` | `OFF_HOST_S3_COMPATIBLE` | `OFF_HOST_SFTP`. **LOCAL_ONLY is not DR-capable.** Never send backups to Soviez SaaS.

## S6
Full restore depth + off-host classification re-certified. LOCAL_ONLY ≠ DR. Evidence: `docs/evidence/security-gate-s6/FULL_RESTORE_DEPTH.md`, `OFF_HOST_BACKUP.md`.
