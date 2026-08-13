# CLI_PROPOSAL.md

Propose only (do not implement):

```bash
sudo soviez.sh --migration-authorization-plan <pair-id>
sudo soviez.sh --migration-authorization-show <authorization-id>
sudo soviez.sh --migration-activate-destination <pair-id>
sudo soviez.sh --migration-activation-status <operation-id>
sudo soviez.sh --migration-activation-retry <operation-id>
sudo soviez.sh --migration-activation-recover <operation-id>
sudo soviez.sh --migration-source-grace-status <source-production-id>
sudo soviez.sh --migration-stage-rebind-status <operation-id>
sudo soviez.sh --migration-phase21-readiness <operation-id>
sudo soviez.sh --migration-phase21-readiness-show <report-id>
sudo soviez.sh --migration-authorization-export <authorization-id>
sudo soviez.sh --migration-authorization-import <package>
```

## Rules

- Exact IDs; confirmation on irreversible ops; TTY vs non-TTY; JSON output; stable exit codes
- Offline import/export of signed packages
- Idempotent activate/retry
- **No** generic disconnected token-consume
- **No** cutover / source purge / default token-refund commands
