# DEPLOY_MAIN_DIFF — Soviez/soviez-deploy Main Integration

## Status

**PENDING** — push not done.

## Publish scope (this cycle)

| Path | Action |
|------|--------|
| `services/registry-gateway/**` | **ADD** — canonical gateway package |
| `soviez.sh` | **UPDATE** — dual wizard (parity with ERP) |

## Canonical gateway decision (D130)

No separate GitHub repository. Gateway lives at:

```
Soviez/soviez-deploy/services/registry-gateway/
```

Local source synced from:

- `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway`
- `soviez-sh/services/registry-gateway/`

## PP-01 mapping

Pre-publish blocker PP-01 (soviez-sh remote) mapped to publish via **Soviez/soviez-deploy** for gateway tree. soviez-sh remote linkage remains **PENDING** for full installer publish.

## Wizard parity

| File | SHA256 |
|------|--------|
| `soviez.sh` | `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841` |

## Remote

| Field | Value |
|-------|-------|
| Remote | `origin` → `https://github.com/Soviez/soviez-deploy.git` |
| Target branch | `main` |
| Pre-push main SHA | **PENDING** |
| Post-push main SHA | **PENDING** |

## Post-push checks

- [ ] `services/registry-gateway/` present with full operator pack
- [ ] No `node_modules/` or `dist/` committed
- [ ] No secrets in `gateway.env.example` (placeholders only)
- [ ] `soviez.sh` SHA256 matches ERP

See `POST_PUSH_VERIFICATION.md`.
