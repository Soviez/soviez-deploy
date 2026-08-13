# Project context (agents)

## Confirmed decision
Canonical installer source is `/soviez-sh`. Legacy `soviez-deploy/soviez.sh` is read-only reference until extraction phases.

## Existing (code)
- SaaS: Supabase Auth, Stripe, purchases/licenses/user_addons, admin grants as `paid` + `admin_provision`.
- ERP: offline Ed25519 `local_license_guard`.
- Installer: monolithic script — domain mandatory, Stage one-per-tenant, `:latest` pull, all-tenant `--update`, unsigned self-update.

## Missing
Device auth, entitlement APIs, private pull sessions, multi-stage, 60-day retention, `--migrate-in`, slot reservation machine, provider-neutral grant table, annual multi-year discounts.

## Unsafe
Unsigned self-update; account-level support fallback; synthetic Stripe IDs; all-tenant update; plaintext license keys.

## Implementation allowed?
**NO** until owner authorizes a numbered phase from MASTER_IMPLEMENTATION_PLAN.md.
