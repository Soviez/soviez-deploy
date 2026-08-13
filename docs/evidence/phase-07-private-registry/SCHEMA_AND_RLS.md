# Schema and RLS — Phase 7

**Migration:** `083_private_registry_pull_foundation.sql`

## Tables

| Table | Purpose |
|-------|---------|
| `registry_releases` | Digest-first release catalog |
| `registry_pull_sessions` | Short-lived pull authorization sessions |
| `registry_pull_session_events` | Append-only audit trail |

## Constraints highlights

- Digest format: `^sha256:[a-f0-9]{64}$` on releases and sessions
- Release unique: `(product_code, release_version, channel, architecture)`
- Session idempotency unique: `(account_id, idempotency_key)`
- Session status enum enforced by CHECK
- Events immutable (trigger blocks UPDATE/DELETE)

## Commercial seed

Inserts `commercial_capability_mappings` row for `private_image_pull` with `source_kind=capability_seed`. **Does not create grants.** Tests insert explicit `commercial_grants`.

## RLS summary

| Table | anon | authenticated | service_role |
|-------|------|---------------|--------------|
| `registry_releases` | DENY ALL | SELECT where `status IN ('approved','published')`; no writes | ALL |
| `registry_pull_sessions` | DENY ALL | SELECT own `account_id = auth.uid()`; no writes | ALL |
| `registry_pull_session_events` | DENY ALL | DENY ALL | ALL |

## Grants

- `authenticated`: SELECT on releases + sessions
- `service_role`: ALL on all three tables

## Certification coverage

Isolated Postgres harness (`certification.test.ts`):

- Published release readable under RLS stub
- Cross-account session SELECT denied
- Anon denied
- Event immutability

See `RLS_SECURITY_MATRIX.md` for full matrix.
