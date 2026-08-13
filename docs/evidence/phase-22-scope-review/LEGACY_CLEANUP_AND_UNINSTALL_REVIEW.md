# Legacy Cleanup and Uninstall Review

## Legacy `soviez-deploy/soviez.sh` — `mode_purge`

- Irreversible tenant teardown: containers, volumes, network, nginx, host dirs
- Typed name confirmation exists
- **No** retain/archive/Stage-selection/Safe Shield/backup-first choreography
- **Classification:** unsafe / obsolete for product Phase 22
- **Rule:** Do not lift `mode_purge` into Phase 22. Future purge (later phase) may study confirmation UX only.

## soviez-sh today

- **No** `src/cleanup/` or `src/uninstall/` product trees
- Exact cleanups: transfer staging, landing, Stage retention, backup delete, image digest cleanup
- Hard ban: `docker … prune` as product step (Phase 15 static gate)

## SaaS messaging drift

Sales/docs referencing `./soviez.sh --purge` point at legacy behavior. Must not be treated as Phase 22 product API.

## ERP

License Guard blocks core module uninstall — integrity only; not host retirement.
