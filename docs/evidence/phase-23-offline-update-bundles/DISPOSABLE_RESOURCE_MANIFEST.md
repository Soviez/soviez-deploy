# DISPOSABLE_RESOURCE_MANIFEST

Run ID: `20260809T201641Z-78190`
Started: 2026-08-09T20:16:41Z
Profile: `default` (pre-existing; required by DOCKER_HOST assumptions)
Temp workspace: `/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T201641Z-78190`

## Ownership labels for newly created cert fixtures
- `soviez.phase23.disposable=1` (existing Phase 23 helper convention)
- `com.soviez.owner=phase23-cert`
- `com.soviez.cert-run=20260809T201641Z-78190` (when applied by this lifecycle / helpers)

## Resources (append-only during run)

| type | id/name | created_utc | notes / cleanup |
|------|---------|-------------|-----------------|
| tmpdir | `/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T201641Z-78190` | 2026-08-09T20:16:41Z | rm -rf exact path only |

## Disposability assessment (DO NOT DELETE)

Profile `default` contains persistent / unrelated resources:

```text
soviez-upd-cand-upd-20260809231316-91cfd08a	soviez/erp:p15-v15-labeled
soviez-upd-pg-cert	postgres:16
soviez-upd-cand-upd-20260809170137-70cd77b2	soviez/erp:p15-v15-labeled
soviez-p16-sftp	soviez-p16-sftp:local
soviez-p16-minio	minio/minio:RELEASE.2024-12-18T13-15-44Z
wab-poc-sidekiq-1	chatwoot/chatwoot:latest
wab-poc-gowa-1	aldinokemal2104/go-whatsapp-web-multidevice:latest
wab-poc-rails-1	chatwoot/chatwoot:latest
wab-poc-redis-1	redis:7-alpine
wab-poc-postgres-1	pgvector/pgvector:pg16
soviez-p17-ubuntu2204	ubuntu:22.04
soviez-p17-ubuntu2404	ubuntu:24.04
soviez-rc-web-pass5-20260806T003013Z	soviez-erp:18.0.1.01.5-local-release-candidate-pass5
soviez-rc-db-pass5-20260806T003013Z	postgres:16
soviez-rc-db-pass4-20260805T220925Z	postgres:16
soviez-rc-db-20260805T203923Z	postgres:16
```

Named volumes include `wab-poc_*` and `soviez-p17-*` — not Phase 23 cert-owned.
Evidence/source/artifact live outside the VM; nevertheless **reusable RC ERP images + unrelated POC DBs** make deletion unsafe.

**Decision: stop only; do not `colima delete`.**
