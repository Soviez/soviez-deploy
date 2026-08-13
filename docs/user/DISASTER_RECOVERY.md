# Disaster Recovery

## Do not confuse backup with DR

| Posture | Meaning |
|---------|---------|
| LOCAL_ONLY | Backup exists on the same host — **not** DR |
| Off-host S3/SFTP (validated) | Can support DR objectives when policy requires |

## Operator expectations

1. Keep verified backups
2. Prefer off-host copies for site-loss scenarios
3. Practice `--restore-test` on disposable paths
4. Untrusted imports always quarantine

Release policy for mandatory off-host DR remains an **owner decision** (`OD-RELEASE-OFFHOST-BACKUP=PENDING`) and does not change engineering certification.
