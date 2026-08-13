# Migration Activation Before Cutover

## Overview

Destination activation in Phase 20 means your new server is **licensed and healthy internally**, but **not yet public**. This is intentional: it lets you verify the migrated system before any DNS or traffic change.

## What “pre-cutover” means

| Aspect | Status |
|--------|--------|
| License binding | Moved to destination |
| ERP login (internal) | Should work |
| Production domain | Still points to **source** |
| Public customer traffic | Still on **source** |
| Outbound mail/payments/webhooks | Neutralized on destination |

## Running activation

After authorization commit:

```bash
./soviez.sh migration destination activate \
  --pair-id <pair-id> \
  --authorization-id <auth-id>
```

## What to verify

1. **Internal health** — modules load, filestore accessible, license guard enabled.
2. **No public route** — destination must not answer on your production domain.
3. **Source still live** — your current production continues serving users.
4. **Backup** — a verified destination backup marker should exist post-activation.
5. **Stages** — selected stages rebound; mandatory failures block readiness.

## Source restrictions

While source is in migration grace, some operations are blocked (updates, cloning, new stages, second migration, etc.). Normal traffic and backups continue.

## Stage rebind warnings

If optional stages fail to rebind, activation may complete with WARNING. Mandatory stage failures block activation/readiness.

## Next steps

- Run Phase 21 readiness check for a formal PASS/WARNING/BLOCKED report.
- **Do not** change DNS or expect traffic to move — that requires Phase 21 authorization (not yet available).

## If activation fails

Destination remains non-public. Token may already be consumed — see [Migration Authorization Recovery](MIGRATION_AUTHORIZATION_RECOVERY.md). Do not attempt DNS cutover manually.
