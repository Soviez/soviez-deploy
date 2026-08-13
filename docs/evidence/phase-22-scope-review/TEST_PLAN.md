# Phase 22 Test Plan (implementation-ready)

## Phase 21 targeting
exact readiness · expired · invalid · dest drift · source drift · traffic owner ≠ dest · rollback still active · active incident · unresolved recovery

## Stabilization
sustained healthy · intermittent HTTP · TLS/DB/filestore/worker failure · queue backlog · mail/webhook/payment failure · duplicate callback/payment · source traffic/writes · DNS/Stage instability · backup failure

## Rollback-window closure
eligible · elapsed-only without health (must fail) · owner confirm missing · active rollback/incident · source write · dest unstable · duplicate closure · lost response · reboot · idempotent retry

## Archive creation
DB/filestore/addons/config/secrets inventory/cert metadata/DNS/Stage/infra · encryption · checksum · exact paths · no symlink escape · no unrelated files · no customer data in metadata manifest

## Archive verification
valid · checksum mismatch · truncated DB · missing filestore · addon/config mismatch · corrupt encrypted · wrong archive/source/License · replay/substitution · DB restore test · full ERP restore if required

## License finalization
exact source License · dest remains bound · one slot · archived state · no second activation/update/Stage/clone · controlled diagnostics · isolated restore · LG enforcement

## Runtime suspension
ERP only · ERP+PG · host remains · provider suspension · reboot recovery · accidental restart prevention · explicit recovery · no host/volume/backup delete

## Credentials
SMTP/payment/webhook/OAuth/DNS/backup disposition · encrypted quarantine · no secret logs · incomplete disposition blocks readiness

## Certificates and DNS
cert retained · near expiry · renewal policy · no revocation · DNS snapshot retained · public route disabled · no broad DNS cleanup

## Stages
none/one/many · optional fail WARNING · mandatory fail BLOCKED · retention unchanged · expired Stage · no source Stage deletion · no cross-Stage

## Retirement readiness
full inventory · unknown resource · orphaned volume/snapshot · unknown DNS/cert/service user · unresolved backup job · legal/owner hold · purge false

## Security
forged closure/manifest · substitution · path traversal · symlink escape · tar bomb · broad cleanup · backup delete · cert revoke · host terminate · source reactivation · second Production · cross-tenant · audit tamper

## Integration (real disposable)
real source/dest · PostgreSQL · filestore · backup target · encrypted archive · restore test · LG archived state · runtime suspension · host reboot · network interruption · **no purge**
