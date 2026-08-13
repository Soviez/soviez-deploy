# TEST_PLAN.md

Implementation-ready matrix (summary; expand to cases in automation).

## Targeting / prerequisites
exact/wrong/expired pair; exact/expired/invalid Phase 19 readiness; source/dest drift; wrong License/account/fingerprint; public dest route; source inactive; token already changed.

## Token entitlement
valid one-token; zero qty; expired/revoked/disputed/refunded; wrong License/account; manual/complimentary/offline grant; provider-neutral.

## Atomic transaction
success; fail before lock; fail after lock before commit; timeout; lost result; same key same/different payload; concurrent duplicates/different destinations; consume once; bind once; grace once.

## License binding
valid source; dest created; no duplicate slot/License; wrong device/UUID/digest denied; LG validates; local tamper denied.

## Source grace
traffic source-owned; ERP up; backup/status OK; update/clone/Stage/second-migrate/rebind denied; reboot survival; no indefinite unrestrict.

## Destination activation
internal healthy; LG; slot count; no public/domain; no mail/pay/webhook; cron policy; internal login per OD; modules/filestore; dest backup if required.

## Split-brain
source traffic / dest future; dual public blocked; duplicate License use; callbacks blocked.

## Stage rebind
none/one/many; expired/wrong parent/entitlement denied; retention unchanged; optional WARNING; mandatory BLOCKED; idempotent; cross-tenant deny.

## Recovery
commit/local-apply mixes; Stage partial; reboot/network after commit; corruption; idempotent replay; commit unknown; compensation.

## Offline
valid/expired/wrong/replay/forged; already-consumed; connected conflict; reconcile; no local invent.

## Security
theft; double spend; forged auth; wrong signer; stale readiness; cross-account/License; Stage hijack; public exposure; LG bypass; grace abuse; unauthorized reversal; secrets; injection; audit tamper.

## Integration E2E
disposable SaaS DB + ledger + resolver + real LG source/dest + Phase 19 staging + Stage + real tx/timeout/retry/reboot; source traffic owner; dest internal only; **no DNS/cutover**.
