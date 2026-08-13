# NO_UPSTREAM_CREDENTIAL_EGRESS — Upstream Secret Boundary

## Verdict

**PASS**

## Invariant

Upstream Docker Hub credentials (`SOVIEZ_UPSTREAM_REGISTRY_USER`, `SOVIEZ_UPSTREAM_REGISTRY_TOKEN`) must **never** appear in:

- HTTP responses to clients
- Pull ticket payloads
- Installer-visible configuration
- Application logs (stdout/stderr)
- Error messages returned to docker/client

## Evidence

### Unit test: token exchange

**File:** `test/gateway.test.ts` — `"REG basic auth token exchange (docker login path)"`

- Upstream secret fixture: `super-secret-hub-token-xyz`
- Assert: `!JSON.stringify(body).includes(UPSTREAM_SECRET)`

**Result:** PASS

### Real pull proof script

**File:** `scripts/real-oci-pull-proof.sh`

- Upstream secret fixture: `hub-secret-must-never-egress`
- Assert token body excludes secret and excludes `pull-user`
- Output field: `"upstream_secret_egress": "NONE"`

**Result:** PASS

### Log scan test

**File:** `test/gateway.test.ts` — `"secrets absent from logs"`

- Captures console output during manifest + blob pulls
- Asserts no match for upstream secret or valid ticket token

**Result:** PASS

## Implementation controls

| Control | Location |
|---------|----------|
| Upstream auth on proxy hop only | `src/proxy.ts` |
| Response bodies contain ticket only | `src/server.ts` |
| Redaction patterns for env/token leaks | `src/redact.ts` |
| `safeLog` / `safeError` wrappers | `src/redact.ts` |

## Client-visible credentials

Clients receive **only** the Soviez pull ticket (short-lived Ed25519 token). Docker may cache this as registry password — expected and bounded by 900s TTL.

## Post-deploy verification

Capture staging gateway access logs + sample pull trace; confirm no Hub PAT substrings: **PENDING**
