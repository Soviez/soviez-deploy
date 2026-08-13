# Code-Grounded Implementation Discovery

**Date:** 2026-07-30  
**Scope:** Analysis, repository foundation, documentation only.  
**Labels:** Existing · Planned · Missing · Unsafe · Requires owner decision · Confirmed decision  

**Authority:** Inspected code under `/Volumes/PortableSSD/soviez-project`. Prior audits used as cross-check, not as sole truth.

---

## 1. Executive verdict

**PASS — DISCOVERY AND PLANNING FOUNDATION COMPLETE** for phases 1–2.

The new modular engine under `/soviez-sh` can be built on:

| Pillar | Verdict |
|--------|---------|
| Sovereignty / offline ERP DRM | **Existing** — `local_license_guard` offline Ed25519 |
| Commercial control plane | **Existing** — Supabase Auth + `purchases`/`licenses`/`user_addons` |
| Admin/offline grants | **Existing** as `status='paid'` + `checkout_routing='admin_provision'` (synthetic Stripe IDs — **Unsafe** long-term) |
| Provider-neutral ledger | **Missing** as first-class model; **Compatible** migration from `paid` + routing |
| Installer modular engine | **Missing** in `/soviez-sh`; legacy monolith **Existing** in `soviez-deploy` |
| Device auth / entitlement APIs / private pull | **Missing** |
| Multi-stage + 60-day retention | **Missing** (legacy = one Stage/tenant; no retention clock) |
| `--migrate-in` sovereign assistant | **Missing** |
| Constitution + planning docs | **Existing** (this task) |

**Implementation is not authorized yet.**

---

## 2. Repository baseline

| Component | Branch | Commit |
|-----------|--------|--------|
| `soviez-saas` | `main` | `2f2f13c655ac42aa976764db56d939bf60a40094` |
| `soviez-deploy` | `main` | `afe6de5be61e8737a730a575c84fe8fb5be0050b` |
| `soviez-sh` | `main` | empty (no commits) |
| `Soviez ERP` | `dev` | `09e2b5556fbba728a21a80268e7ed125a84655d5` (behind origin/dev by 9) |

Safe checks: `bash -n` PASS on both installer copies; copies **IDENTICAL** (226971 bytes). ShellCheck not installed.

---

## 3. Current multi-repo architecture

```text
soviez-saas (Next.js/Vercel) ── Stripe webhooks ── Supabase Postgres/Auth
        │
        │  Ed25519 mint / portal OTP
        ▼
Customer paste key ──► Soviez ERP local_license_guard (offline)
        ▲
soviez-deploy/soviez.sh ── docker pull soviez/soviez-erp:latest ── host Docker/Nginx
soviez-sh/  ◄── NEW canonical source (docs only this phase)
```

No Supabase Edge Functions directory. No entitlement API for installer. SaaS `/api/cli-script` rewrites to public installer fetch (unsigned).

---

## 4. Current payment and commercial-grant architecture

**Existing:**

- Table `purchases` with `purchase_status` enum `pending|paid|refunded|failed` (`001_initial_schema.sql`).
- Stripe Checkout + webhook fulfillment (`src/app/api/webhooks/route.ts`, `fulfill-checkout-session.ts`).
- Admin grants via `admin_provision_purchase` / `admin_provision_addon` (`064`, `066`) and `src/lib/admin-provisioning.ts`.
- Marker: `checkout_routing = 'admin_provision'`, `manual_payment_method` free text (`061`).
- Synthetic `stripe_checkout_session_id` values `admin-grant-*` / `admin-addon-*` (column `NOT NULL UNIQUE`).
- Support inventory: `user_addons`; admin support uses synthetic `stripe_subscription_id` `admin-provision-{purchaseId}` (`admin-addon-entitlements.ts`).

**Missing:** `payment_provider` enum; settlement table separate from purchase; customer offline payment approval queue.

---

## 5. Exact admin/offline provisioning behavior

| Path | Behavior | Label |
|------|----------|-------|
| Admin grant license | Inserts `purchases` `status=paid`, slots=1, fake session id | Existing |
| Admin grant addon | Same + optional `user_addons` for support slugs | Existing |
| Customer bank-transfer pending approval | Not implemented | Missing |
| SME/startup | Coupon → still Stripe checkout | Existing |
| Audit | `admin_audit_log` via `logAdminAction` after grant | Existing (after mutation) |

**Conclusion:** `purchase.status='paid'` **does** cover admin/offline **today**. Stripe ID is syntactically required, not commercially required.

---

## 6. Exact Stripe behavior

| Event | Handler | Effect |
|-------|---------|--------|
| `checkout.session.completed` | `fulfillCheckoutSession` | `paid`, slots, addons |
| `customer.subscription.updated/deleted` | `stripe-subscription-pipeline.ts` | sync `current_period_end` / expire |
| `charge.refunded` | `stripe-refund-pipeline.ts` | purchase `refunded`, license `revoked` |
| `charge.dispute.*` | `stripe-dispute-pipeline.ts` | license `disputed`/`revoked`/`active` |
| Idempotency | `processed_stripe_events` | Existing |
| Signature | `constructEvent` | Existing |

Support: `mode: subscription`, interval `month|year`, quantity 1. No multi-year `interval_count`.

---

## 7. Provider-neutral payment/grant gap analysis

| Need | Today | Gap |
|------|-------|-----|
| Ask “valid grant for capability?” | Scattered RPCs on `paid` + slugs | Missing capability layer |
| provider = stripe/manual/admin/… | Only `checkout_routing` text | Missing first-class provider |
| Avoid fake Stripe IDs | Required NOT NULL session id | Unsafe / Planned migration |
| Refunds across providers | Stripe pipelines only | Missing neutral reversal API |
| Future gateways | Hard-wired Stripe client | Missing adapter interface |

**Recommended compatible model (Planned):**

1. Keep `purchases.status='paid'` as interim commercial settlement flag (backward compatible).
2. Add `payment_provider` (`stripe|manual_offline|admin_grant|complimentary|future_gateway|migration_credit`) and nullable `provider_reference`.
3. Introduce `commercial_grants` / `capability_entitlements` views or tables keyed by account + optional `license_id` + capability + validity — populated from Stripe fulfill, admin grant, and future adapters.
4. Stop minting synthetic Stripe IDs for new admin grants once column nullable or dual-write complete.
5. Entitlement APIs query grants, never `stripe_*` presence.

---

## 8. Exact License Slot lifecycle

**Existing** (`065_license_fingerprint.sql`, `037` `get_available_license_slots`):

```text
paid purchase (slots=1, used=0) → AVAILABLE
generate_secure_license_1to1 FOR UPDATE → INSERT licenses + used=1 → CONSUMED
```

- Consume at SaaS mint, not ERP activate.
- Soft revoke does not free slot; admin purge (`068`) does.
- Checkout always grants 0 or 1 slot (`create-checkout-session.ts`, `fulfill-checkout-session.ts`).
- Reservation states AVAILABLE/RESERVED/KEY_ISSUED/ACTIVATED: **Missing**.

---

## 9. Exact support lifecycle

**Existing:** slugs `technical-support-monthly` / `technical-support-annual`; subscriptions; optional `target_license_id`; entitlement RPCs treat monthly≡annual and allow unbound fallback (`067`).

**Confirmed decision:** new sales annual-only with `product_updates`; monthly must not authorize updates.

**Missing:** capabilities JSON, multi-year terms, year-discount admin table, early-renewal stack from `max(valid_until, now)`, strict license binding without fallback.

---

## 10. Exact Stage lifecycle

**Existing** (`soviez-deploy/soviez.sh`):

| Command | Function | Notes |
|---------|----------|-------|
| `--stage` | `mode_stage` ~5424 | One DB name `stage`; refresh = drop+recreate |
| `--dropstage` | `mode_dropstage` ~5605 | Safe Shield neutralized |
| `--liststage` | `list_stage_environments` ~6303 | No license_id |
| Domain | `prompt_stage_fqdn` / `stage.<prod>` | Mandatory FQDN today |
| SSL | `provision_tenant_https` | Self-signed fallback allowed |
| MAC/UUID | Same as prod | License parity |

**Missing:** multi-stage naming, Stage entitlement check, 60-day retention, signed challenge endpoint, start/stop first-class commands, Cloud linkage.

---

## 11. Exact update lifecycle

**Existing:** `mode_update` ~4409 — default **all tenants** (prod + stage); optional single web name; `docker pull :latest`; schema upgrade; may leave web offline on failure.

**Unsafe** vs constitution: implicit all-tenant update; unpinned latest.

**Missing:** single-tenant mandatory; annual `product_updates` gate; digest pin; pull session.

---

## 12. Exact migration-token lifecycle

**Existing:**

- Addon slug `ip-migration-token`; credits on profile/license.
- ERP deactivate wizard + HMAC receipt (`LICENSE_FLOW.md`, `deactivation-receipt.ts`).
- SaaS `begin_license_migration` / `migrate_license_ip` / cancel (`070`) — burns token, rebinds FP/key.
- Fail-closed `SOVIEZ_MIGRATION_SECRET` / `LICENSE_MIGRATION_SECRET`.

**Missing:** installer `--migrate-in` sovereign assistant; streaming; destination landing; resumable workers.

---

## 13. Exact Docker image publishing and pull lifecycle

**Existing publish:** `Soviez ERP/.github/workflows/deploy.yml` — Hub login secrets → build → verify wkhtmltox → push `soviez/soviez-erp:latest` and `v18.0.1.01.0`.

**Existing pull:** `APP_IMAGE="soviez/soviez-erp:latest"`; bare `docker pull`.

**Missing:** private repo; digest-pinned release manifest; pull-only backend token; client short-lived sessions; offline OCI archive; client-side signing verification.

---

## 14. Exact domain and SSL behavior

**Existing:**

- Production `--new`: `prompt_domain_confirmed` ~2843 — mandatory FQDN.
- Stage: mandatory FQDN derived or custom.
- `dns_validation_loop` ~2869 — interactive y/n/**force**; not silent infinite poll.
- `provision_tenant_https` ~3244 — self-signed then Certbot; LE failure keeps self-signed.

**Gaps vs constitution:**

- `force` DNS override — **Unsafe** escape hatch.
- Self-signed accepted as “success” — Stage final acceptance must require valid cert (**Planned** hardening; transitional policy **Requires owner decision**).
- No signed environment challenge endpoint — **Missing**.

---

## 15. Exact current installer command map

| Flag | Status | Notes |
|------|--------|-------|
| `--init` | Existing | Host only — no DB/activation |
| `--new` | Existing | Tenant + domain + SSL + MAC + DB |
| `--formsetup` / `--formssl` / `--formworkers` | Existing | Resume/heal |
| `--stage` / `--dropstage` / `--liststage` | Existing | One stage/tenant |
| `--update [web]` | Existing | All tenants if no arg — Unsafe vs constitution |
| `--backup` / `--backup-list` | Existing | Restore Missing |
| `--change-domain` | Existing | |
| `--purge` / `--rebuild` | Existing | Destructive |
| `--migrate-in` / `--restore` | Missing | |
| Auto-activate consent | Missing | |

---

## 16. Existing reusable functions (extraction candidates)

From legacy script clusters: `update_self` (replace), DNS/SSL (`dns_validation_loop`, `provision_tenant_https`), Docker lifecycle, Stage (`mode_stage`, neutralize, filestore clone), backup, env sheets, topology, maintenance shell (`run_odoo_maintenance_stdin` — reuse for ORM activate).

---

## 17. Unsafe functions or patterns

1. `update_self` / `ensure_local_soviez_sh` — unsigned overwrite.
2. `APP_IMAGE=...:latest` + all-tenant update.
3. Weekly `docker system prune -af`.
4. `--purge` / `--rebuild` irreversible.
5. DNS `force` override.
6. Certbot `--register-unsafely-without-email`.
7. Support unbound fallback RPCs.
8. Synthetic Stripe IDs as grant identity.
9. Slot consume before local activate success (for future auto path).

---

## 18. Proposed `/soviez-sh` architecture

```text
soviez-sh/
  PRODUCT_CONSTITUTION.md
  PROJECT_STATE.md
  docs/{ai,user,dev}/
  src/
    commands/     # init, new, stage, update, backup, migrate-in, ...
    lib/          # docker, nginx, dns, ssl, env, ui, disclosure
    entitlement/  # client for SaaS APIs (no secrets)
    registry/     # pull-session consumer + cleanup
    ops/          # systemd workers, state machine, resume
  schemas/        # OpenAPI / JSON schemas (docs)
  scripts/bundle.sh → dist/soviez.sh
  tests/
  dist/           # generated only
```

**Confirmed:** never edit `dist/` by hand.

---

## 19. Proposed command contracts (Planned)

| Command | Requires | Forbidden |
|---------|----------|-----------|
| `--init` | Host bootstrap; optional account auth (**owner decision**) | Auto-activate |
| `--new <tenant>` | Slot reserve; domain; SSL; digest pull; Auto\|Manual activate | Implicit multi-tenant |
| `--stage …` | Stage entitlement; unique domain; SSL; retention disclosure | Account-wide entitlement |
| `--update <prod-tenant>` | Exact one tenant; annual product_updates | No-arg all-tenants |
| `--backup` / restore | Local only | SaaS upload |
| `--migrate-in` | Dual-server; streaming; token flow | SaaS data proxy |

---

## 20. Proposed persistent-operation architecture

**Missing today** (except `--formsetup` resume).

Planned: local state dir (`/var/soviez/ops/<operation_id>/`) with JSON state machine; systemd units on source/destination; idempotent step runners; reconcile on reattach; WAITING_FOR_DNS with Try Again / Abort Safely.

---

## 21. Proposed provider-neutral commercial ledger

See §7. Minimum concepts:

- `commercial_transactions` (optional) or enhanced `purchases`
- `payment_settlements` / reversal events
- `commercial_grants` → capability allocations
- `license_slot_allocations`
- Audit: actor, reason, provider, external ref, validity, target license, quantity, revocation

Admin grants = first-class `provider=admin_grant`.

---

## 22. Proposed entitlement APIs

Device auth +:

- `/entitlements/install/check`
- `/slots/reserve|release|ack`
- `/entitlements/activate/auto`
- `/entitlements/update/check`
- `/entitlements/stage/check`
- `/registry/pull-session`

All capability checks via grants, not Stripe column presence. **Never** reuse `has_active_support_subscription*` for updates/Stage.

---

## 23. Proposed private-registry architecture

Private Hub or GHCR + SaaS-held pull-only org token + short-lived `image_pull_sessions` bound to operation_id, device pubkey, repo, digest, expiry. Installer temp `DOCKER_CONFIG` → pull digest → wipe. Offline: signed OCI archive.

---

## 24. Proposed automatic/manual activation flow

On `--new` after MAC+DB+web:

1. Consent Auto vs Manual (mandatory).
2. Auto: disclose metadata → ticketed mint → `action_activate_soviez_license` via stdin shell → ack.
3. Manual: leave unconfigured; portal OTP mint + paste.

Official ORM only. No SQL ICP injection.

---

## 25. Proposed multi-stage architecture

Replace single `stage` name with parameterized `stage-<id>` DB/web/network/domain/addons. Resource checks. Same-fingerprint model retained per constitution unless proven unsafe. Entitlement bound to `license_id`.

---

## 26. Proposed mandatory Stage domain/SSL workflow

1. Require unique FQDN.
2. Show challenge token on destination signed landing.
3. DNS attempt → success or Try Again / Abort Safely.
4. HTTPS + cert validation + environment signature.
5. Accept Stage only when all pass.

Remove silent infinite poll (already interactive). Restrict or eliminate `force` for Stage acceptance.

---

## 27. Proposed 60-day retention architecture

Local Stage metadata: `created_at`, `expires_at=created+60d`, warnings, preservation flag. Cron/worker warns then Safe Shield drop. Independent of Stage entitlement expiry.

---

## 28. Proposed safe update architecture

Require `--update <exact-prod-tenant>`; entitlement check; pull digest via session; recycle that unit (+ optional linked stages only if explicitly selected); do not interrupt mid-migration on token expiry.

---

## 29–30. Sovereign migration & source retirement

As constitution §§15–16. Stream; dual workers; maintenance landing; token integration; source retained by default.

---

## 31. Connected/offline parity plan

Every connected capability maps to an offline artifact (signed image, entitlement package, fingerprint export, receipt exchange). Manual activation remains gold-standard offline path (**Existing**).

---

## 32. Required changes to soviez-saas

Provider fields; grants/capabilities; term discounts; Stage SKU; slot reservations; device auth; entitlement APIs; pull sessions; remove unbound fallbacks for new checks; annual-only new sales; keep monthly recognition for legacy.

---

## 33. Required changes to local_license_guard

**Minimal.** Prefer zero behavior change for activation/migration/quarantine/shadow-lock. Optional: installer-friendly activate helper if shell insufficient. UI copy matrix vs MAC drift. No phone-home.

---

## 34. Required changes to installer

Rebuild under `/soviez-sh`: modularize; remove unsigned self-update / all-tenant default / latest; add disclosure, device auth client, ops state, multi-stage, retention, migrate-in, restore.

---

## 35–38. Migrations / APIs / Admin UX / Customer UX

Documented in `MASTER_IMPLEMENTATION_PLAN.md` phases 3–13 and `docs/dev/*`.

---

## 39. Security findings

| Sev | Finding |
|-----|---------|
| Critical | Unsigned installer self-update; plaintext license keys; in-process DRM bypass |
| High | `:latest` + all-tenant update; unbound support fallback; synthetic Stripe IDs; public image |
| Medium | DNS force; self-signed acceptance; prune cron; soft-revoke no slot free |
| Low | README omits destructive flags; empty soviez-sh history |

Also: `soviez-saas/private.pem` present — verify live vs orphan (**Requires owner decision**).

---

## 40. Privacy / data-egress findings

Legacy installer does not upload DB/filestore to SaaS (**Existing** good). Future APIs must keep egress contract. Migration assistant must never SaaS-proxy dumps (**Confirmed**).

---

## 41. Compatibility risks

- Changing entitlement RPCs may break Nancy/ticket premium if not dual-read.
- Making `stripe_checkout_session_id` nullable needs careful migration.
- Multi-stage rename breaks existing single `stage` envs — need migration path.
- Forbidding all-tenant update changes operator muscle memory.

---

## 42. Failure/recovery model

Local ops state; idempotent steps; abort before cutover preserves source; after cutover retain source; pull/activate retries without double-burn; Stage retention separate from entitlement.

---

## 43. Test matrix

See `docs/ai/TEST_REQUIREMENTS.md`. Minimum: slots concurrency, cross-license denial, monthly≠updates, Stage license bind, migration token one-use, device replay, pull restrictions, guard activation/deactivation/quarantine/shadow-lock suites.

---

## 44. Documentation plan

Trees under `docs/ai|user|dev` created this phase as discovery/planning. Implementation phases must update docs in the same PR/change set.

---

## 45–48. Phased plan / weights / gates / next phase

See `MASTER_IMPLEMENTATION_PLAN.md` and `PROJECT_STATE.md`.

**Next allowed phase:** Phase 3 — Provider-neutral commercial-grant model (owner authorization required).

**Suggested next prompt:** “Authorize Phase 3 only: design and implement provider-neutral commercial grant schema + dual-read entitlement adapters in soviez-saas, with tests and docs; do not change installer behavior or Stripe live products yet.”

---

## 49. Remaining owner decisions

1. Multi-year billing shape (`interval_count` vs prepaid).
2. Monthly subscriber migration path.
3. Slot commit point (KEY_ISSUED vs ACTIVATED).
4. Stage concurrency caps / resource formula.
5. Self-signed transitional policy vs hard fail for Stage/Production acceptance.
6. Whether `--init` requires Cloud auth.
7. Soft-revoke frees slot?
8. `past_due` grants updates/Stage?
9. `private.pem` disposition.
10. Pull ERP `dev` (+9) before guard work?
11. Registry: private Hub vs GHCR.
12. First git commit on `soviez-sh` timing.

---

## 50. Exact references index

| Topic | Reference |
|-------|-----------|
| Purchases schema | `soviez-saas/supabase/migrations/001_initial_schema.sql` |
| Admin provision | `064_admin_provision_purchase.sql`, `066_admin_provision_addons.sql`, `src/lib/admin-provisioning.ts` |
| Support entitlement | `067_fix_admin_provision_addon_entitlement.sql` |
| Slot consume | `065_license_fingerprint.sql` `generate_secure_license_1to1` |
| Available slots | `037_audit_remediation.sql` `get_available_license_slots` |
| Stripe webhooks | `src/app/api/webhooks/route.ts` |
| License mint API | `src/app/api/license/generate/route.ts` |
| Migration RPC | `070_migration_session_lock.sql` |
| ERP activate | `local_license_guard/tools/license_tools.py` `store_license_activation`; `models/soviez_license_mixin.py`; `controllers/main.py` |
| Installer Stage/Update/DNS/SSL | `soviez-deploy/soviez.sh` functions cited above |
| Image CI | `Soviez ERP/.github/workflows/deploy.yml` |
| DRM blueprint | `LICENSE_FLOW.md` |
| Prior discoveries | `docs/LICENSING_BILLING_ENTITLEMENT_AUDIT_2026-07-29.md`, `docs/ai/COMMERCIAL_ENTITLEMENT_AND_AUTO_ACTIVATION_DISCOVERY.md` |

---

*End of code-grounded discovery. No product implementation performed.*
