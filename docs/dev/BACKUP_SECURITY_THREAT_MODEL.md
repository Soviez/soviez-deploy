# Backup Security Threat Model (Phase 16)

## Assets
Production DB dumps, filestore archives, encryption passphrases, destination credentials, manifest HMAC key, inventory metadata, restore candidates.

## Adversaries
| Threat | Mitigation |
|--------|------------|
| SaaS exfiltration of backups | No SaaS destination; egress forbid on payloads |
| Cross-tenant restore | Exact production_id / license / database_uuid checks |
| Cross-host restore | Host identity mismatch deny |
| Remote cleartext backups | Encryption mandatory for S3/SFTP |
| Secret leakage in logs/manifest | Scrub forbidden keys; passphrase via env/file |
| SFTP MITM | `StrictHostKeyChecking=yes` |
| Destructive overwrite without confirm | Candidate-first + `--confirm` / TTY gates |
| Retention deleting last good / pins | Protected classes + pin flag |
| Slot burn via restore candidate | Temporary identity; no permanent slot |
| Path traversal on filestore | Refuse unsafe roots (`/`, empty) |

## Non-goals
Cryptographic DRM against Full Root; unbreakable offline media theft without passphrase strength; WAL/PITR forensics.

## Residual
Full Root on the customer host can read local secrets and disable controls — disclosed, not DRM.
