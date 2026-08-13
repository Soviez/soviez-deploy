# Existing Migration Capability Inventory — Phase 17 Scope Review

**Scope:** Inventory only. No runtime changes.  
**`src/migration/`:** does not exist.

## Classification legend

| Class | Meaning |
|-------|---------|
| **Reusable** | Use as-is or with thin adapter in Phase 17 |
| **Refactor** | Reuse pattern; extend for migration IDs/ops |
| **Unsafe** | Must not be reused as cross-host migrate without redesign |
| **Obsolete** | Superseded or naming collision only |
| **Missing** | Required for Phase 17; not present |
| **Duplicate name** | Homonym; not server migration |

---

## 1. Legacy / naming — `--merge-in`

| Field | Value |
|-------|-------|
| File/function | *None* in soviez-sh or `soviez-deploy/soviez.sh` |
| Owner phase | Planned 17+ as `--migrate-in` (docs) |
| Side | N/A |
| Connected/offline | N/A |
| Exact-target | N/A |
| Identity | N/A |
| Persistence | N/A |
| Secrets | N/A |
| Ops engine | N/A |
| Reboot | N/A |
| Class | **Missing** (never implemented; “merge-in” string absent) |
| Transfers payloads | No |
| Changes live state | No |
| Consumes entitlement | No |

See `LEGACY_MERGE_IN_REVIEW.md`.

---

## 2. Ops schema “migration” (Phase 14) — name collision

| Field | Value |
|-------|-------|
| File/function | `src/ops/migration.sh` — `soviez_ops_migrate_*` |
| Owner phase | **14** |
| Side | Local host |
| Connected/offline | Local |
| Exact-target | Operation ID |
| Identity | Op canonical schema |
| Persistence | `$SOVIEZ_OPS_ROOT` |
| Secrets | None in migrate path |
| Ops engine | Core |
| Reboot | Via Phase 14 recovery |
| Class | **Duplicate name** / **Reusable** for op-state only — **not** host migration |
| Transfers payloads | No |
| Changes live state | Op metadata only |
| Consumes entitlement | No |

---

## 3. Conflict stub `migrate` (Phase 14 foreshadow)

| Field | Value |
|-------|-------|
| File/function | `src/ops/conflicts.sh` — `soviez_ops_conflict_decide` pairs `migrate`↔`update`/`production_update`/`production_backup`/`production_restore` |
| Owner phase | **14** matrix; migrate ops **17+** |
| Side | Would apply both hosts when ops exist |
| Class | **Reusable** stub |
| Transfers / live / token | No / gates concurrency / No |

---

## 4. Device Authorization (Phases 5–8)

| Field | Value |
|-------|-------|
| File/function | `src/auth/device_keys.sh`, `device_client.sh`, `signing.sh` |
| Owner phase | **5–8** |
| Side | Destination/host ↔ SaaS |
| Connected/offline | **Connected** for authorize; keys local |
| Exact-target | Device fingerprint |
| Identity | Ed25519 device keypair |
| Persistence | Local device key material (0600) |
| Secrets | Private key local only |
| Ops engine | Used by `--new` |
| Class | **Reusable** for destination bootstrap trust to SaaS |
| Transfers payloads | No business data |
| Changes live state | Device registration |
| Consumes entitlement | No Migration Token |

---

## 5. License Slot / fingerprint (Phase 6–8)

| Field | Value |
|-------|-------|
| File/function | `src/license/fingerprint.sh`, `activate_orm.sh`, `choice.sh`, `ack.sh`; `src/api/slots_client.sh` |
| Owner phase | **6–8** |
| Side | Destination |
| Connected/offline | Connected for slot ledger |
| Exact-target | Slot + fingerprint |
| Identity | `tenant:op:hostname` fingerprint material |
| Class | **Reusable** for Phase **21** activation; **Unsafe** if Phase 17 burns a permanent slot |
| Transfers payloads | Activation key only |
| Changes live state | Slot bind / license issue |
| Consumes entitlement | License Slot (not Migration Token) |

---

## 6. Signed installer / Registry (Phase 7)

| Field | Value |
|-------|-------|
| File/function | `src/api/registry_client.sh`, `src/registry/pull_client.sh`, `manifest_verify.sh`; `services/registry-gateway/` |
| Owner phase | **7** |
| Side | Destination |
| Connected/offline | Connected pull; offline packages adjacent |
| Exact-target | Digest-pinned release |
| Identity | Pull session + Ed25519 tickets |
| Class | **Reusable**; allowlist includes `migration_bootstrap` (doc) |
| Transfers payloads | Image blobs only |
| Changes live state | Images on host |
| Consumes entitlement | Registry/session; not Migration Token |

**Gap:** signed **installer script** bootstrap product for migrate dest is still **Missing**.

---

## 7. Activation `--new` (Phase 8)

| Field | Value |
|-------|-------|
| File/function | `src/commands/new.sh` — `soviez_cmd_new_run` |
| Owner phase | **8** |
| Side | Fresh destination-like host |
| Class | **Refactor** pattern for bootstrap SM; **Unsafe** as migrate (creates Production + slot) |
| Transfers payloads | No (empty DB) |
| Changes live state | **Creates** Production |
| Consumes entitlement | License Slot |

---

## 8. Stage origin identity (Phase 11)

| Field | Value |
|-------|-------|
| File/function | `src/stage/inventory.sh`, `production.sh`, `clone.sh`, `engine.sh`, `neutralization.sh` |
| Owner phase | **11** |
| Side | Same host as Production |
| Class | **Reusable** for Stage inventory discovery; **not** cross-host transfer |
| Transfers payloads | Yes on clone (same host) |
| Changes live state | Stage only |
| Consumes entitlement | Stage entitlement |

---

## 9. Domain/SSL (Phase 12)

| Field | Value |
|-------|-------|
| File/function | `src/ssl/readiness.sh`, `engine.sh`, `challenge.sh`, `letsencrypt.sh`; CLI try-again/abort |
| Owner phase | **12** |
| Side | Environment host |
| Class | **Reusable** inspection + UX patterns; Phase **18** owns migrate landing/DNS |
| Transfers payloads | No |
| Changes live state | Cert/nginx when run |
| Consumes entitlement | No |

---

## 10. Unified Operation Engine (Phase 14)

| Field | Value |
|-------|-------|
| File/function | `src/ops/*` — registry, locks, conflicts, recovery, adapters |
| Owner phase | **14** |
| Side | Host-local |
| Class | **Reusable** — Phase 17 ops must register here |
| Transfers payloads | No |
| Changes live state | Op state |
| Consumes entitlement | No |

---

## 11. Safe Update candidate identity (Phase 15)

| Field | Value |
|-------|-------|
| File/function | `src/update/license_guard_candidate.sh`; offline `src/update/offline.sh` |
| Owner phase | **15** |
| Side | Same host |
| Identity | Temporary candidate; inherits DB UUID; uses `SOVIEZ_MIGRATION_SECRET` for LG HMAC (≠ Migration Token) |
| Class | **Reusable analogy**; **Unsafe** as cross-host migrate identity |
| Transfers payloads | Shares Prod DB during update |
| Consumes entitlement | No Migration Token |

---

## 12. Backup export/import (Phase 16)

| Field | Value |
|-------|-------|
| File/function | `src/backup/export.sh`, `import.sh`; `src/restore/compatibility.sh` |
| Owner phase | **16** |
| Side | Source export / dest import store |
| Exact-target | Host identity stamped; cross-host restore **denied** |
| Class | **Reusable** for backup prerequisite / package shape; **not** Phase 17 stream |
| Transfers payloads | **Yes** (backup packages) — **out of Phase 17 runtime** |
| Changes live state | Backup store; restore applies later |
| Consumes entitlement | No |

---

## 13. Migration Token commercial foundation (SaaS)

| Field | Value |
|-------|-------|
| File/function | Capability `migration_token`; slug `ip-migration-token`; `resolve_capability_entitlement`; grants in commercial ledger |
| Owner phase | SaaS commercial (pre–sovereign migrate) |
| Side | Account/License wallet |
| Class | **Reusable** eligibility check in Phase 17; **burn wire = Phase 20** |
| Transfers payloads | No |
| Consumes entitlement | On begin/consume paths (not Phase 17) |

---

## 14. SaaS migration-token resolver / hardware migrate

| Field | Value |
|-------|-------|
| Canonical | `begin_license_migration`, `migrate_license_ip`, `cancel_license_migration` (`070_migration_session_lock.sql`; API `api/license/migrate/*`) |
| Obsolete | `consume_ip_migration_token` — superseded by session lock |
| Owner phase | SaaS existing; installer wire **Phase 20** |
| Class | **Reusable** (Phase 20); Phase 17 may **eligibility-only** |
| Consumes | `begin` **reserves**; complete **consumes**; cancel restores |

---

## 15. Host reactivation / deactivation

| Field | Value |
|-------|-------|
| SaaS+ERP | Deactivation receipt HMAC + migrate_license_ip rebind |
| Installer | No sovereign migrate deactivate path yet |
| Class | **Phase 20–21** — **excluded** from Phase 17 |
| Changes live state | License rebind / source deactivate |
| Consumes | Migration Token (via reserved session) |

---

## 16. Tenant / host identity

| Field | Value |
|-------|-------|
| File/function | `src/tenant/identity.sh`, `secrets.sh`; hostname stamps in ops/backup |
| Owner phase | **8** / **14** / **16** |
| Class | **Reusable** / **Refactor** for migration-pair bindings |

---

## 17. Offline package patterns

| Field | Value |
|-------|-------|
| Stage offline | `src/commands/stage_offline.sh` |
| Update offline | `src/update/offline.sh` |
| Class | **Reusable** pattern for offline pairing/installer package (OD pending) |
| Phase 23 | Full offline product — out of Phase 17 |

---

## 18. Legacy init / migration secret

| Field | Value |
|-------|-------|
| File/function | `soviez-deploy/soviez.sh` — `--init`; `generate_migration_secret` / `ensure_migration_secret` |
| Class | Legacy **Reusable concept**; soviez-sh `--init` **Missing**; secret is LG HMAC not Migration Token |
| Unsafe | Legacy unsigned self-update path |

---

## Summary counts

| Class | Count (approx) |
|-------|----------------|
| Missing (Phase 17 core) | 6+ |
| Reusable | 15+ |
| Unsafe if misused | 4 |
| Obsolete / duplicate name | 3 |
| Deferred to 18–22 | Streaming, DNS landing, token burn, activate, purge |
