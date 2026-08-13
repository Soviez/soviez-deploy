# RLS security matrix — Phase 7

**Migration:** `083_private_registry_pull_foundation.sql`  
**Certification:** `src/lib/registry/e2e/certification.test.ts`

## `registry_releases`

| Role | SELECT | INSERT | UPDATE | DELETE | Policy |
|------|--------|--------|--------|--------|--------|
| `anon` | ✗ | ✗ | ✗ | ✗ | Deny all |
| `authenticated` | ✓ published/approved only | ✗ | ✗ | ✗ | Status filter |
| `service_role` | ✓ | ✓ | ✓ | ✓ | Bypass RLS |

## `registry_pull_sessions`

| Role | SELECT | INSERT | UPDATE | DELETE | Policy |
|------|--------|--------|--------|--------|--------|
| `anon` | ✗ | ✗ | ✗ | ✗ | Deny all |
| `authenticated` | ✓ own account only | ✗ | ✗ | ✗ | `account_id = auth.uid()` |
| `service_role` | ✓ | ✓ | ✓ | ✓ | Bypass RLS |

## `registry_pull_session_events`

| Role | SELECT | INSERT | UPDATE | DELETE | Policy |
|------|--------|--------|--------|--------|--------|
| `anon` | ✗ | ✗ | ✗ | ✗ | Deny all |
| `authenticated` | ✗ | ✗ | ✗ | ✗ | Deny all |
| `service_role` | ✓ | ✓ | ✓ | ✓ | Bypass RLS |

## API write path

All session/release mutations go through **service_role** admin client in Next.js route handlers — never client-side Supabase keys.

## Certification tests

| Test | Result |
|------|--------|
| Published release visible to authenticated owner context | PASS |
| Cross-account session SELECT empty | PASS |
| Anon SELECT denied | PASS |
| Event UPDATE blocked by trigger | PASS |
| Capability seed mapping exists | PASS |

## Gateway RLS

Gateway has **no database access** — not subject to Supabase RLS.

## Known limitation

Full JWT `auth.uid()` cross-account denial under production Supabase Auth stack uses same pattern as Phases 5–6 (isolated PG with auth stub).
