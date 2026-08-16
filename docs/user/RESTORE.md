# Restore

## Trusted vs untrusted

| Class | Path |
|-------|------|
| Trusted / managed | Restore with integrity verification |
| External / untrusted | **Must** enter S4 quarantine |

```text
untrusted restore
→ quarantine
→ scan
→ validation
→ explicit promotion
```

A restored DB is treated as **potentially hostile** until scanned: it may contain cron, mail servers, webhooks, or other persistence that should not run on Production until approved.

## Commands

```bash
soviez.sh --restore <production-id> --backup <backup-id> [--confirm]
soviez.sh --restore-test <backup-id>
soviez.sh --restore-as-stage <backup-id> --stage-domain FQDN [--confirm]
soviez.sh --restore-status|cancel|retry|recover|rollback|cleanup <operation-id>
soviez.sh --security-quarantine-status|scan|promote|reject [ID]
```

## Full restore depth

Certified restore covers DB + filestore + manifest/config with verification (see Security S6 / Phase 25 evidence).
