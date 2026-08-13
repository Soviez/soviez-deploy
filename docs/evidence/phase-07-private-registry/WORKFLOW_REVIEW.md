# Workflow review — Phase 7 prep CI

**File:** `Soviez ERP/.github/workflows/phase7-registry-release-metadata.prep.yml`  
**Status:** Prep only — **not enabled as default pipeline**

## Validation

| Check | Result |
|-------|--------|
| YAML syntax (`python yaml.safe_load`) | **OK** |
| Triggers | `workflow_dispatch` only (push commented) |
| Permissions | `contents: read`, `id-token: write` |

## Safety boundaries (documented in workflow)

- Does **not** change live Docker Hub repository visibility
- Does **not** rotate production credentials
- Does **not** register releases to production SaaS without approval
- Emits **candidate** metadata (`status: candidate`) — not customer-authorized

## Steps review

| Step | Purpose | Live impact |
|------|---------|-------------|
| Checkout + Buildx | Standard CI | None |
| Docker Hub login | Build push to immutable version tag | Uses existing secrets; no visibility change |
| Derive version | VERSION file or git SHA | None |
| Build and push | `soviez/soviez-erp:${VERSION}` only | Adds immutable tag (not `:latest` authority) |
| Capture digest | `buildx imagetools inspect` | Metadata only |
| Write candidate JSON | `artifacts/release-candidate.json` | Artifact only |
| Sign manifest | Placeholder when secret present | Optional |
| Export OCI tar | Offline bundle input | Artifact only |
| Upload artifacts | CI artifact storage | None |
| Reminder step | Human approval boundary | None |

## Integration path (future)

1. CI produces candidate artifact
2. Release process approves → SaaS catalog row `approved`/`published`
3. Installer resolve API returns digest + signed manifest
4. Separate owner approval for Hub private cutover

## Phase 7 gate

Workflow reviewed and syntactically valid. **Not live-run** in this session.
