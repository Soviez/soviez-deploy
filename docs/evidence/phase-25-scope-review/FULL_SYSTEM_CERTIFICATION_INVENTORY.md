# Full-system certification inventory

Surfaces requiring final certification (orchestrate owners; do not fork):

## Installer CLI
`--new`, `--stage*`, `--update*`, offline-bundle/offline-update/trust cmds, backup/restore cmds, migration cmds, ops cmds, security-status/scan/phase25-readiness (eng), status/reattach/retry/recover/cancel families; connected + offline; TTY/non-interactive; interrupted recovery.

## Installation
Clean connected/offline; Ubuntu 22.04/24.04; amd64; Docker/PG compatibility; Production domain + valid SSL; failure/retry/recovery.

## Activation
Automatic on `--new`; manual; offline; invalid License/Device; slot conflict; SaaS unavailable; support expired but ERP valid; no phone-home.

## Licensing / entitlement
One License / permanent Production slot; provider-neutral entitlement; annual support; legacy monthly where preserved; grants; exact Device/env; no runtime shutdown on support expiry; no accidental slot/token mutation.

## Updates (P15)
Connected exact-target; signed; Registry short-lived creds; candidate/backup/validate/switch/rollback; reboot/recovery; entitlement/support expiry.

## Offline updates (P23)
Signed bundle; air-gap apply; mandatory backup; OCI; candidate; DB/addon migration; local switch/rollback; result receipt; later reconciliation; unreconciled independence; no network during apply.

## Stage (P11/13)
Create/clone/refresh/rebuild; expiration; countdown banner; final backup; Safe Shield; Needs Action; 14-day default; 60-day max; entitlement; resource-limited count.

## Backup/restore (P16)
Local/S3/SFTP; DB/filestore; encryption; checksums; restore; restore verification; recovery; no protected-op bypass.

## Migration (P17–22)
Discovery→pairing→bootstrap→transfer→auth→rebind→activation→landing→DNS→health→cutover→rollback window→archive→retirement readiness; **no purge**.

## Security (P24)
Signed enforcement; unsigned/fake deny; key pinning; purpose separation; replay deny; Registry lockdown; Docker cleanup; service-role/private-key absent from dist; secret scan; test-bypass quarantine; multi-tenant; sovereignty.

## License Guard
Connected/disconnected/SaaS down; support expiry; no runtime disable; status/recovery available.

## SaaS backend
Schema clean/upgrade; entitlement/slots/Stage/update/Registry/offline/migration/reconcile; multi-tenant; idempotency; security; typecheck/lint/build. **UI frozen**.

## Compatibility
Third-party Odoo 18 addon surface stability; no Studio dependency for certified features.
