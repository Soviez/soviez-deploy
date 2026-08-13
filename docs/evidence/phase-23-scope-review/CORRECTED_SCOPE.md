# CORRECTED_SCOPE — Phase 23

## Corrected title
**Phase 23 — Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application**  
(Master-plan short title retained: Offline bundles)

## Corrected objective
Entitled connected issuance of a signed offline update bundle; manual transfer to air-gapped Soviez ERP; offline verify/inspect/plan; mandatory Phase 16 backup; Phase 15 candidate apply/validate/rollback; signed result receipt; later explicit reconciliation — without phone-home, permanent Registry credentials, or business-data egress.

## Inclusions
Exact License/environment/Device targeting; entitlement resolution (`product_updates` + `offline_update_bundle`); connected request/issuance/export; signed authorization + manifest; Registry digest export on connected worker; full-image (+ addon/migration) packaging; digest/signature/compatibility/expiry/replay; offline import/inspect/plan/apply/status/retry/recover/rollback; mandatory verified backup; isolated candidate (Phase 15 reuse); result receipt + reconciliation; operation-engine integration; air-gapped docs; no periodic phone-home.

## Exclusions
Source purge/host destruction; App Store/marketplace; customer business-data export; online-only update enforcement; forced startup subscription checks; remote shell/unattended remote update; new production activation; License slot transfer; migration cutover; permanent Docker login; Registry creds in bundle; automatic live fleet rollout; Phase 24–25 behavior; emergency recovery-bundle product (default deferred); delta-only critical path.
