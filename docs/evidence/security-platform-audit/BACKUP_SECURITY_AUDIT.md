# Backup security audit

Capabilities exist for DB/filestore/config backups in modular paths; encryption/off-host/retention/restore-test maturity varies by path.

```text
same-server backup ≠ disaster-recovery backup
```

Future: require off-host option for Production certification; checksum; no secret leakage in backup meta logs; optional immutable storage.
