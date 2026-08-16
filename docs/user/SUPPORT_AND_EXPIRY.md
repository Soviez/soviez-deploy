# Support and Expiry

## Support expiry

```text
Support expiry does NOT stop ERP.
```

- ERP continues to operate.
- **Product updates** are blocked according to entitlement policy only (`UPDATE_CAPABILITY_EXPIRED` class denials).
- Backup, restore, status, diagnostics, and recovery remain available.
- **Soviez.sh platform / security / compatibility self-update remains allowed** even when Technical Support is expired.

## Stage entitlement expiry

```text
Stage entitlement expiry blocks create/clone/refresh/rebuild according to policy.
It does NOT shut down or delete an already-existing Stage merely because entitlement expired.
```

Existing Stages can still be listed, started, stopped, backed up, and dropped by operator action (subject to retention deletion jobs).

## SaaS unavailable

ERP continues. Connected features that require SaaS (new activation, Registry pull, entitlement refresh) wait or fail closed without killing runtime. Local commands (`--version`, `--list`, `--stage-list`, diagnostics, recovery) remain available.
