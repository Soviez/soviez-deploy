# Test results — Phase 7

**Date:** 2026-07-30  
**Session:** Verified in Phase 7 PASS gate

## Phase 7 primary suites

| Command | Location | Result |
|---------|----------|--------|
| `npm run test:phase7` | soviez-saas | **9 pass** |
| `npm run test:phase7-db` | soviez-saas | **8 pass** |
| `npm test` | soviez-sh/services/registry-gateway | **14 pass** |

### Phase 7 unit coverage (`logic.test.ts`)

- Registry constants and signing domain separation
- Release manifest sign/verify
- Pull ticket sign/verify
- Offline bundle verify
- Digest parse + local match contract
- Repository allowlist
- Architecture normalization
- Release status denial mapping

### Phase 7 DB certification (`certification.test.ts`)

- Migration 083 applies cleanly in isolated harness
- Published release catalog insert
- Pull session lifecycle + idempotency
- RLS cross-account denial
- Event immutability
- Capability seed mapping presence

### Gateway tests (`gateway.test.ts`)

- Auth challenge and ticket verification
- Manifest graph authorization
- Blob scope enforcement
- Method/route denial
- Token exchange
- Mock upstream streaming
- Expired/invalid ticket handling

## Regression suites (same session)

| Command | Result |
|---------|--------|
| `test:commercial-closure` unit | **24 pass** |
| `test:commercial-closure` db | **13 pass** |
| `test:phase5` | **14 pass** |
| `test:phase5-db` | **8 pass** |
| `test:phase6` | **6 pass** |
| `test:phase6-db` | **6 pass** |

## Build / lint

| Check | Result |
|-------|--------|
| ESLint | No warnings |
| TypeScript | pass |
| `npx next build` | pass — registry API routes compiled |
| Gateway typecheck + build | pass |

## Not executed

| Check | Reason |
|-------|--------|
| Live Supabase migrate | ENOTFOUND — production host not targeted |
| Live Docker Hub pull | Mock upstream only |

## Total new tests (Phase 7)

**31** (9 + 8 + 14) in primary Phase 7 suites.
