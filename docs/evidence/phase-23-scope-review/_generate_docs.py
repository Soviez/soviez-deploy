#!/usr/bin/env python3
"""Generate Phase 23 scope-review evidence docs (documentation only)."""
from pathlib import Path

evid = Path("/Volumes/PortableSSD/soviez-project/soviez-sh/docs/evidence/phase-23-scope-review")
evid.mkdir(parents=True, exist_ok=True)

D = {}

D["BASELINE.md"] = """# BASELINE — Phase 23 Scope Review

## Repositories
| Repo | Path | Notes |
|------|------|-------|
| Primary | `/Volumes/PortableSSD/soviez-project/soviez-sh` | Installer `0.22.0-phase22`; SHA256 `dabd4ca5628afc7b6ffbe17796163779891bdf0f2ff70fb5698a55a2254879fb` |
| SaaS | `/Volumes/PortableSSD/soviez-project/soviez-saas` | HEAD `2f2f13c655ac42aa976764db56d939bf60a40094`; pre-existing dirty tree preserved |
| ERP | `/Volumes/PortableSSD/soviez-project/Soviez ERP` | HEAD `03af6199effdad32fd7f82119a90515159389801`; not modified |
| Legacy | `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh` | Reference only |

## Certified progress
- Phases 16–22: PASS
- Progress: **98%** (unchanged)
- Phase 11.5: FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED
- Phase 23 implementation: NOT AUTHORIZED
- Phase 24+: UNAUTHORIZED

## Dirty-state preservation
soviez-sh has no commits on main and many untracked artifacts; not cleaned. SaaS/ERP dirty trees preserved. This mission is documentation-only under soviez-sh evidence + AI state docs.
"""

D["MASTER_PLAN_PHASE23_CONFIRMATION.md"] = """# MASTER_PLAN_PHASE23_CONFIRMATION

## Canonical topic (verified)
From `docs/ai/MASTER_IMPLEMENTATION_PLAN.md` § Phase 23:

| Field | Canonical content |
|-------|-------------------|
| Title | **Phase 23 — Offline bundles** |
| Objective | Signed installer/image/entitlement/update/migration offline packages. |
| Acceptance | Air-gapped lab install+activate+update path |
| Complexity | High |
| Dependencies | 7, 8, 15 |
| Owner approval | Required |
| Numeric weight | **Not assigned** in master plan table |

## Discrepancy / title correction
Recommended expanded title:

**Phase 23 — Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application**

Assessment:
- Canonical topic confirmed: Offline bundles.
- Master-plan objective is broader than updates alone (install+activate+update packages).
- Phase 8/17 already cover substantial offline install/activate foundations.
- Phase 15 ships a minimum `--offline-package` path explicitly “not full Phase 23”.
- Corrected **product focus**: first-class offline **update** delivery (signed full bundles, Registry export, `offline_update_bundle`, reconciliation), under the Offline bundles umbrella.
- Migration offline packages remain Phase 20; purge is **not** Phase 23.
"""

D["CORRECTED_SCOPE.md"] = """# CORRECTED_SCOPE — Phase 23

## Corrected title
**Phase 23 — Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application**  
(Master-plan short title retained: Offline bundles)

## Corrected objective
Entitled connected issuance of a signed offline update bundle; manual transfer to air-gapped Soviez ERP; offline verify/inspect/plan; mandatory Phase 16 backup; Phase 15 candidate apply/validate/rollback; signed result receipt; later explicit reconciliation — without phone-home, permanent Registry credentials, or business-data egress.

## Inclusions
Exact License/environment/Device targeting; entitlement resolution (`product_updates` + `offline_update_bundle`); connected request/issuance/export; signed authorization + manifest; Registry digest export on connected worker; full-image (+ addon/migration) packaging; digest/signature/compatibility/expiry/replay; offline import/inspect/plan/apply/status/retry/recover/rollback; mandatory verified backup; isolated candidate (Phase 15 reuse); result receipt + reconciliation; operation-engine integration; air-gapped docs; no periodic phone-home.

## Exclusions
Source purge/host destruction; App Store/marketplace; customer business-data export; online-only update enforcement; forced startup subscription checks; remote shell/unattended remote update; new production activation; License slot transfer; migration cutover; permanent Docker login; Registry creds in bundle; automatic live fleet rollout; Phase 24–25 behavior; emergency recovery-bundle product (default deferred); delta-only critical path.
"""

D["EXISTING_OFFLINE_BUNDLE_CAPABILITY_INVENTORY.md"] = """# EXISTING_OFFLINE_BUNDLE_CAPABILITY_INVENTORY

Legend: R=reusable | F=refactor | U=unsafe/incomplete | O=obsolete | D=duplicate risk

| # | Primitive | Location | Owner | Assessment |
|---|-----------|----------|-------|------------|
| 1 | `offline_update_bundle` | SaaS `079`; entitlements catalog | Phase 4 | **R** seed; product_not_launched; no SKU mapping yet |
| 2 | `product_updates` | SaaS 079 + annual map; `src/update/entitlement.sh` | 4/9/15 | **R** exact-License |
| 3 | Annual update eligibility | annual-support + update | 9/15 | **R** |
| 4 | Short-lived private_image_pull | 083 + registry-gateway | 7 | **R** export worker only |
| 5 | Phase 15 update candidate flow | `src/update/*` | 15 | **R** must reuse |
| 6 | Image digest pinning | release/registry | 7/15 | **R** |
| 7 | Addon manifests | update + LG | 15/ERP | **F** |
| 8 | Custom-addon allowlist | LG + validate | 15 | **F** |
| 9 | Phase 16 backup prerequisite | update/backup + backup engine | 16 | **R** |
| 10 | Phase 17 offline pairing packages | migration/pairing/offline.sh | 17 | **R** patterns; not update bundles |
| 11 | Phase 20 offline auth package | migration/authorization/offline.sh | 20 | **R** / **D** if conflated |
| 12 | Device PoP | Phase 5 | 5 | **R** |
| 13 | Signing / trust roots | device, migration sign, release manifests | multi | **F** need purpose keys |
| 14 | Operation engine | src/ops | 14 | **R** |
| 15 | Rollback checkpoints | update/rollback + interrupt | 15 | **R** |
| 16 | Update retry/recovery | update interrupt/recover | 15 | **R** |
| 17 | CLI `--offline-package` | cli + update | 15 | **U** minimum ≠ Phase 23 |
| 18 | Registry credentials | gateway tickets | 7 | **R** short-lived; **U** if persisted |
| 19 | Artifact storage | SaaS registry APIs | 7+ | **F** |
| 20 | Legacy offline deploy | soviez-deploy | legacy | **O/U** |
| 21 | Refund/revoke/dispute | commercial ledger | 3/4 | **R** deny issuance |
| 22 | License Guard independence | ERP LG | ERP | **R** |
| 23 | Phase 23 readiness report | migration/phase23_readiness | 22 | **R** report-only; implements_offline_bundles=false |
| 24 | Phase 24 boundary | MASTER | plan | Security hardening — separate |

### Phase 15 `src/update/offline.sh` gaps
Signature check is non-cryptographic string gate (**U**); no `offline_update_bundle` check (**F**); replay consumed on import before apply (**F**); no OCI packaging/Registry export/receipt/reconcile; comment: not full Phase 23.
"""

D["PHASE_4_ENTITLEMENT_OVERLAP.md"] = """# PHASE_4_ENTITLEMENT_OVERLAP

- `product_updates`: boolean, license-scoped; annual materializes with exact License.
- `offline_update_bundle`: boolean, license-scoped, time_bound; foundation seed only; **no commercial mapping** yet.
- `private_image_pull`: operation-scoped; connected export only.
- Monthly technical_support does not map product_updates (fail closed).

Phase 23 issuance should require both `product_updates` and `offline_update_bundle` on exact License. Provider-neutral. Owner decides if offline_update_bundle is included in annual, sold separately, or admin-grant only.
"""

D["PHASE_15_UPDATE_OVERLAP.md"] = """# PHASE_15_UPDATE_OVERLAP

Reuse mandatory: targeting, entitlement pattern, preflight, capacity, candidate, upgrade, validate, switch, rollback, interrupt/recovery, digest-pinned release, ops sync, image ownership.

Do **not** create a second update engine. Phase 23 orchestrates Phase 15 with offline mode + verified staged release.

Gaps: crypto trust-root verify; OCI payload; addon/migration packaging; separate authorization object; result receipt; reconciliation; offline_update_bundle; honest clock/revocation.
"""

D["PHASE_16_BACKUP_OVERLAP.md"] = """# PHASE_16_BACKUP_OVERLAP

Reuse update backup gate + Production backup/restore/verify/encryption/pin.

Phase 23: fresh local VERIFIED backup mandatory before mutation; pin rollback; no deletion; restore-tested recommended (owner); block apply on backup failure; local path needs no network.
"""

D["PHASE_17_OFFLINE_IDENTITY_OVERLAP.md"] = """# PHASE_17_OFFLINE_IDENTITY_OVERLAP

Reusable: quarantine import, signature gates, seen-hash replay, Device fingerprint.

Boundary: pairing/activation packages ≠ update bundles. Share patterns only; distinct schemas.
"""

D["PHASE_20_OFFLINE_AUTHORIZATION_OVERLAP.md"] = """# PHASE_20_OFFLINE_AUTHORIZATION_OVERLAP

Existing: `soviez.migration_authorization_offline_package.v1` with package_id, authorization_id, public_signature, ledger offline-register.

Boundary: distinct from update bundles (`soviez.offline_update_bundle.v1`). Reuse pairing of package+auth IDs and replay concept only.
"""

D["LEGACY_OFFLINE_UPDATE_REVIEW.md"] = """# LEGACY_OFFLINE_UPDATE_REVIEW

Legacy `soviez-deploy/soviez.sh` is reference-only. Do not port unsigned self-update, permanent Registry login, or phone-home. Phase 15+ is authoritative for updates.
"""

D["OFFLINE_BUNDLE_DEFINITION.md"] = """# OFFLINE_BUNDLE_DEFINITION

```
bundle/
  manifest.json
  manifest.sig
  authorization.json
  authorization.sig
  compatibility/
  images/          # OCI layout
  addons/
  migrations/
  metadata/
  checksums/
  trust/           # public roots only
  docs/
```

Deterministic. No customer DB/filestore/secrets/Registry tokens.
"""

D["BUNDLE_FORMAT_OPTIONS.md"] = """# BUNDLE_FORMAT_OPTIONS

| Option | Pros | Cons |
|--------|------|------|
| tar.zst + OCI + JSON + detached sigs | Deterministic, compressible | Need path/symlink rules |
| Encrypted tar.zst | Confidentiality | Key distribution (owner) |
| Pure OCI only | Image-centric | Weak auth/docs/addons |
| Zip | Familiar | Weaker determinism; bombs |

## Recommended default
Deterministic **tar.zst** + OCI image layout + canonical JSON manifest + detached **Ed25519** signatures. Payload encryption optional (owner); if used, wrap to Device/License public material — never password-only in bundle.
"""

D["BUNDLE_MANIFEST_MODEL.md"] = """# BUNDLE_MANIFEST_MODEL

Signed canonical fields (minimum): schema_version, bundle_id, bundle_type, authorization_id, account_id, license_id, target_environment_id, target_device_fingerprint, current_version_constraints, source/target installer versions, current/target ERP image digests, current/target addon manifest digests, update_path, min/max source versions, db/pg/arch/os/runtime constraints, required_free_disk, estimated_temp_disk, required_ram, required_backup_state, payload inventory/sizes/digests/signatures, addon refs, custom_addon_hashes, migration script list, rollback assets, release_notes refs, known_warnings, required_confirmations, created_at, not_before, expiry, signer, trust_root_id, replay_policy, reconciliation_requirement, reuse_policy, entitlement metadata, no_business_data=true, no_secrets=true.
"""

D["BUNDLE_TYPE_MODEL.md"] = """# BUNDLE_TYPE_MODEL

## Full bundle — mandatory first-class
All required target images/addons/assets. Air-gap reliable.

## Delta bundle — optional / deferred unless proven
Exact source digest + complete fallback required. No delta-only critical recovery.

## Emergency recovery bundle — deferred by default
Not silently in Phase 23; requires separate owner authorization.
"""

D["ENTITLEMENT_MODEL.md"] = """# ENTITLEMENT_MODEL

| Capability | Role |
|------------|------|
| product_updates | Authorizes entitled product updates (exact License) |
| offline_update_bundle | Authorizes issuance of offline delivery artifact |
| private_image_pull | Connected export worker only — not on air-gapped server |
| technical_support | Support; monthly never grants updates |

Recommended: both product_updates + offline_update_bundle at issuance; exact License; deny refunded/disputed/revoked; provider-neutral; **no consumable quantity**; immutable issuance record; exact License/device/version binding; post-issuance entitlement expiry does not void unexpired bundle unless revoked before use (honest offline limit).
"""

D["BUNDLE_AUTHORIZATION_MODEL.md"] = """# BUNDLE_AUTHORIZATION_MODEL

Signed object includes: authorization_id, account_id, license_id, entitlement_grant_ids, target_environment_id, target_device_fingerprint, current/target digests, bundle_id, bundle_type, issuance_reason, not_before, expiry, max_apply_count, replay_policy, revocation_status_at_issuance, signer, signature, reconciliation_requirement, offline_apply_allowed=true, network_required_during_apply=false.

Targeting: A License-only; B License+environment; **C License+environment+Device (recommended)** with separate hardware-replacement reissue path.
"""

D["ISSUANCE_LIFECYCLE.md"] = """# ISSUANCE_LIFECYCLE

requested → validating_entitlement → resolving_release → building_payload → signing_bundle → verifying_bundle → issued → downloaded/exported → applied_offline → result_reconciled

Failures: entitlement_denied, target_mismatch, release_not_compatible, payload_build_failed, signature_failed, verification_failed, expired, revoked_before_export, reconciliation_pending, recovery_required.
"""

D["SIGNING_AND_TRUST_CHAIN.md"] = """# SIGNING_AND_TRUST_CHAIN

Distinct purpose keys: offline bundle, authorization, release, addon; root/intermediate. Ed25519 for manifests/authorization; OCI digests for images; pinned public trust roots on offline server; private keys never in bundle; canonical JSON serialization.
"""

D["KEY_ROTATION_AND_REVOCATION.md"] = """# KEY_ROTATION_AND_REVOCATION

Rotation with overlap. Signed revocation/trust packages. Honest limit: air-gapped hosts cannot learn post-issuance revocation without a newer signed package. No real-time CRL claim.
"""

D["REPLAY_MODEL.md"] = """# REPLAY_MODEL

Track bundle_id, authorization_id, operation_id, apply_count, first_seen, applied_at, result, target fingerprint, manifest digest.

Import/inspect may repeat. Successful apply once per exact environment. Failed pre-mutation does not consume apply. Post-mutation → same operation recover/rollback. No generic fleet-reusable Production bundle initially.
"""

D["EXPIRATION_AND_CLOCK_MODEL.md"] = """# EXPIRATION_AND_CLOCK_MODEL

Recommended defaults (owner-confirm): export link short-lived hours; authorization 7 days; offline apply window 30 days; receipt no destructive expiry.

Clock: signed issuance timestamps; last-seen trusted-time; detect rollback; no expiry bypass via clock rollback; offline clock-warning policy.
"""

D["PAYLOAD_MODEL.md"] = """# PAYLOAD_MODEL

May contain: installer artifact, ERP OCI archive, digests, addons+sigs, DB migrations, config templates, release metadata, rollback refs, checksums, public trust, docs.

Must not contain: customer DB/filestore/attachments/secrets, passwords, Device/TLS private keys, Registry/Docker/SaaS secrets, unrestricted logs.
"""

D["REGISTRY_EXPORT_MODEL.md"] = """# REGISTRY_EXPORT_MODEL

Connected export worker: verify entitlement+auth → short-lived scoped Registry access → pull exact digest → export OCI → verify digest → remove credentials → package+sign.

Exact repo/digest only; no permanent Docker config; no creds in bundle; private artifact storage; signed issuance record.
"""

D["ADDON_PACKAGING_MODEL.md"] = """# ADDON_PACKAGING_MODEL

Official registry-first addons; approved custom addons with hash+signature; dependency graph; ERP compatibility; migrations/rollback notes. Preserve third-party Odoo 18 interfaces. Recommend **block** unsigned custom addons for Production offline apply. No customer secrets; no automatic Studio dependency.
"""

D["COMPATIBILITY_GATE.md"] = """# COMPATIBILITY_GATE

Issuance + apply validate: License, Device/env, installer versions, ERP digests, arch/OS, runtime, PG major, DB UUID, addon set, custom hashes, disk/RAM, backup, rollback assets, migration continuity, no unsupported skip, no silent downgrade, no concurrent migration/update. Material mismatch blocks apply.
"""

D["OFFLINE_IMPORT_AND_INSPECTION.md"] = """# OFFLINE_IMPORT_AND_INSPECTION

Conceptual CLI (not implemented): offline-bundle-inspect/plan/import; offline-update-apply/status/retry/recover/rollback; offline-update-result-export/show.

Controlled staging; no exec from untrusted USB; verify signatures before extract; path traversal/symlink/archive-bomb guards; free space; dry-run; typed confirm; JSON; stable codes; no secret logs; no auto network.
"""

D["MANDATORY_BACKUP_MODEL.md"] = """# MANDATORY_BACKUP_MODEL

Reuse Phase 16. Before mutation: exact Production, fresh VERIFIED backup, pinned rollback, storage, ownership, DB+filestore consistency, encryption. Block on failure. No backup deletion.
"""

D["OFFLINE_APPLY_MODEL.md"] = """# OFFLINE_APPLY_MODEL

inspect → verify sig/auth/target/compat/expiry/replay → backup → stage → load OCI → stage addons/migrations → isolated candidate → migrate → validate → switch → validate Production → rollback window → sign result receipt.

Reuse Phase 15 architecture — no second engine.
"""

D["ROLLBACK_AND_RECOVERY_MODEL.md"] = """# ROLLBACK_AND_RECOVERY_MODEL

Cover pre-mutation abort; candidate/migration/validation/switch/post-switch failures; reboot; power loss; disk-full; corrupt import; receipt loss.

Invariants: Production unchanged before switch; rollback image+backup available; failed candidate ≠ Production; reboot-survivable; idempotent resume; no second entitlement usage; no duplicate receipt; no online dependency for recovery.
"""

D["RESULT_RECEIPT_MODEL.md"] = """# RESULT_RECEIPT_MODEL

Signed: receipt_id, bundle_id, authorization_id, license_id, environment_id, device_fingerprint, operation_id, source/target digests, apply times, result, backup_id, rollback/validation state, warnings, failure_code, addon manifest digest, final image digest, signer, signature, reconciliation_status.

No business data / unrestricted logs.
"""

D["RECONCILIATION_MODEL.md"] = """# RECONCILIATION_MODEL

Explicit connected upload of receipt. SaaS verifies signature; marks applied/failed/rolled_back.

ERP must not disable if never reconciled. May block conflicting future issuance until reconciled (owner). Admin/manual resolution. No hidden periodic upload.
"""

D["OFFLINE_INDEPENDENCE_MODEL.md"] = """# OFFLINE_INDEPENDENCE_MODEL

ERP continues if support/update entitlement expires, receipt unreconciled, SaaS/Registry unavailable, or bundle never applied. Only new protected update issuance/application may be denied. Backup/restore/status/diagnostics/recovery remain available.
"""

D["CONFLICT_MATRIX.md"] = """# CONFLICT_MATRIX

Conflicts with connected update; other offline update; backup; restore; migration 19–22; License rebind; Stage ops; source archive/retirement; addon install; manual container mutation; Registry pull; rollback; bundle import; reconciliation; Device replacement; entitlement revocation; same-target other bundle.

Minimum: one_active_update_per_environment; one_active_bundle_apply_per_bundle_target; one_active_candidate_switch_per_production.
"""

D["SECURITY_THREAT_MODEL.md"] = """# SECURITY_THREAT_MODEL

Threats include forged bundle/manifest/auth; trust-root substitution; downgrade/rollback/stale; replay; theft; Device clone; clock rollback; OCI/addon substitution; path traversal/symlink/archive bomb; exec before verify; USB malware; embedded secrets; Registry leak; key compromise; offline revocation lag; receipt forgery; entitlement/LG/update bypass; cross-tenant issuance; shell injection; privilege escalation.

Mitigations: Ed25519+pinned roots; exact targeting; replay registry; verify-before-extract; quarantine; Phase 15 candidate; no creds in bundle; honest offline revocation limits; no phone-home.
"""

D["DATA_EGRESS_MODEL.md"] = """# DATA_EGRESS_MODEL

Forbidden: business DB/filestore/attachments/records/accounting/unrestricted logs/passwords/private keys.

Permitted connected metadata: account/license/environment IDs, device fingerprint, installer version, digests, addon manifest digests, approved custom hashes, entitlement/authorization/bundle IDs, requested target version, compatibility result, public signatures, timestamps, signed result state, non-sensitive failure codes.

No hidden telemetry. Prefer dedicated artifact storage / Registry export over embedding large payloads in SaaS responses.
"""

D["OWNER_DECISIONS.md"] = """# OWNER_DECISIONS

Owner must approve (not silently decided): confirmed objective/title; full vs delta; format/compression/encryption/recipient; entitlement combo and whether offline_update_bundle is separately paid; quantity vs unlimited; License/Device binding; hardware-replacement reissue; expiries; max apply; fleet policy; algorithms; key hierarchy/rotation; revocation package; clock policy; addon/unsigned policies; version span/skip/downgrade; backup freshness/restore-test; validation; rollback window; DB downgrade honesty; reconciliation rules; artifact storage/retention/download count; USB guidance; emergency recovery scope (recommend defer); Phase 24 boundary; Phase 23 progress-accounting weight (propose 1).

See recommended defaults in FINAL_REPORT.
"""

D["IMPLEMENTATION_DECOMPOSITION.md"] = """# IMPLEMENTATION_DECOMPOSITION

Proposed (not implemented):

```
src/offline_bundle/          # codes, model, manifest, authorization, signing, trust, targeting, compatibility, expiry, replay, import, inspect, staging, receipt, reconcile, engine
src/offline_bundle/export/   # entitlement, release, registry, images, addons, migrations, package, sign, verify, storage, report
src/offline_update/          # preflight, backup, candidate, image_import, addons, migrations, validate, switch, rollback, recover, result, engine
src/offline_trust/           # roots, rotation, revocation, clock, verify
src/offline_reconciliation/  # export, import, verify, conflict, report, engine
src/commands/                # offline_bundle.sh, offline_update.sh, offline_reconciliation.sh
```

Thin orchestration must call Phase 15 update and Phase 16 backup APIs.
"""

D["TEST_PLAN.md"] = """# TEST_PLAN — Implementation-ready

A. Master-plan/scope: canonical topic; conflicts; Phase 24 boundary; no purge/App Store leak  
B. Entitlement: annual+offline_update_bundle; missing capabilities; expired/revoked/refunded/disputed; wrong License; provider-neutral  
C. Issuance: exact targeting; compatible/incompatible; Registry timeout; signature; deterministic rebuild; no credential leak  
D. Manifest/signature: tamper; wrong signer; unknown/revoked trust; digest mismatch  
E. Targeting/replay: wrong License/env/Device; clone; repeat inspect; duplicate apply; recover  
F. Expiry/clock: not-before; expired; clock rollback; trusted-time; new revocation package  
G. Payload: OCI; addons; unsigned; corrupt; bomb; traversal; symlink; disk full  
H. Compatibility: skip version; arch/OS/PG/UUID/addon; conflicting op  
I. Backup: fresh/stale/fail; restore-test; pinned rollback  
J. Offline apply: happy path; failures; rollback; reboot each step; no internet  
K. Reconciliation: export/import; forged; conflict; unreconciled; manual resolution  
L. Security: forged/downgrade/replay/trust-root/cred-leak/exec-before-verify/LG bypass/cross-tenant  
M. Integration lab: disposable ledger; Registry fixture; OCI; signed bundle; disconnected dest; PG/filestore; candidate; backup; rollback; reboot; later reconcile
"""

D["GIT_DIFF_SUMMARY.md"] = """# GIT_DIFF_SUMMARY

Documentation-only Phase 23 scope review.
- Created: docs/evidence/phase-23-scope-review/*
- Modified (docs only): PROJECT_STATE.md, docs/ai/CURRENT_STATE.md, docs/ai/MASTER_IMPLEMENTATION_PLAN.md, docs/ai/DECISION_LOG.md
- Runtime code / dist/soviez.sh / installer version / progress: unchanged
"""

D["FINAL_REPORT.md"] = """# FINAL_REPORT — Phase 23 Scope Review and Correction

**Verdict:** `PASS — PHASE 23 SCOPE REVIEW AND CORRECTION COMPLETE`

## Canonical confirmation
Master plan Phase 23 = **Offline bundles** (signed installer/image/entitlement/update/migration offline packages; air-gapped lab install+activate+update). **Purge is not Phase 23.**

## Corrected title
**Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application** (short alias: Offline bundles)

## Progress / artifact (unchanged)
Progress **98%**. Installer **0.22.0-phase22**. SHA256 `dabd4ca5628afc7b6ffbe17796163779891bdf0f2ff70fb5698a55a2254879fb`.

## Weight
No numeric weight in master plan for Phase 23. Remaining **2%** for Phases 23–25.
- Proposed progress-accounting weight: **1**
- Real complexity: **High** (do not equate to 1% engineering effort)

## Recommended defaults (assessed, not applied)
Full bundle mandatory; delta deferred; tar.zst+OCI+Ed25519; License+env+Device binding; product_updates+offline_update_bundle; no quantity consume; immutable issuance; apply window 30d; auth/export shorter-lived; one successful apply per exact target; no fleet-generic Production bundle; short-lived Registry creds on export worker only; fresh verified backup; reuse Phase 15; no phone-home; signed receipt; explicit reconcile; ERP continues if unreconciled; conflicting future bundles may require reconcile.

## Structured codes (proposed)
OFFLINE_BUNDLE_* and OFFLINE_UPDATE_* family as listed in mission prompt (REQUIRED through PHASE24_NOT_READY) — to be implemented only when Phase 23 is authorized.

## Implementation
NOT authorized. No runtime modules. No bundles built/published. No live Registry/SaaS/customer changes. No commit.

## Next allowed action
Owner reviews OWNER_DECISIONS.md and explicitly authorizes Phase 23 **implementation**. Phase 24 remains unauthorized.
"""

for name, body in D.items():
    (evid / name).write_text(body.strip() + "\n")
    print("wrote", name)
print("total", len(list(evid.glob("*.md"))))
