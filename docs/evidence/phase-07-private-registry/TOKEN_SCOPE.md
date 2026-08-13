# Token scope — Phase 7

## Pull ticket scope

| Property | Value | Enforced by |
|----------|-------|-------------|
| `scope` claim | `"pull"` only | Gateway ticket verify |
| Repository | Single allowlisted repo | Gateway path match |
| Digest | Single root manifest digest | Gateway manifest auth |
| Blobs | Config + layers from manifest graph | Gateway blob auth |
| Push / DELETE | Denied | Gateway method filter |
| Catalog / tags | Denied | Gateway route filter |
| Cross-session | Denied | Ticket `session_id` + graph isolation |
| Cross-account | Denied | Ticket claims (audit) |

## What the client receives

| Credential | Lifetime | Storage |
|------------|----------|---------|
| `pull_ticket` | 15 min (default) | Temp docker login password only |
| `client_token` | 15 min | Opaque; hashed in SaaS (`client_token_hash`) |
| `registry_username` | Session UUID | Temp docker login username |

## What the client never receives

- Docker Hub username/password/token
- Hub organization pull secret
- SaaS service role key
- Release manifest private key
- Ticket signing private key

## Hub credentials (gateway only)

| Env var | Scope |
|---------|-------|
| `SOVIEZ_UPSTREAM_REGISTRY_USER` | Pull-only Hub account |
| `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` | Pull-only token |
| `SOVIEZ_UPSTREAM_REGISTRY_HOST` | Default `registry-1.docker.io` |

Used only in server-side Basic auth to upstream. Redacted in logs (`redact.ts`).

## Docker client limitation

After `docker login`, the Docker daemon stores auth in the temp config directory — not device PoP per blob. Security relies on:

1. Short ticket TTL
2. Digest + repo binding
3. Blob graph enforcement
4. Temp config deletion
5. Session revoke/complete clearing SaaS-side hashes

## Refresh invalidation

Each refresh replaces `active_ticket_jti_hash`. Prior ticket remains valid until its own `exp` (acceptable window ≤ 15 min).

## Tests

- Ticket verify rejects `scope !== pull`
- Gateway denies PUT/POST/PATCH/DELETE
- Gateway denies `/v2/_catalog` and `/tags/list`
