# Registry Gateway — public client contract

Dedicated Soviez-operated OCI gateway for private ERP image pulls.

**Canonical model:** `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`  
**Protocol:** `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`  
**Client source (this repo):** `src/registry/`, `src/api/registry_client.sh`

## Repository boundary

| Concern | Location |
|---------|----------|
| Client ticket request, temporary Docker auth, digest enforce, cleanup | `Soviez/soviez-deploy` (`src/registry/`, etc.) |
| Gateway **server** implementation | Internal only: local `soviez-registry-gateway/` (not published here) |

## Client responsibilities

- Speak Docker Registry HTTP API V2 as a **pull client** against `SOVIEZ_REGISTRY_GATEWAY_URL`
- Use short-lived credentials from the SaaS Registry ticket flow
- Never persist Hub/upstream credentials; never write installer Docker auth into `~/.docker/config.json`
- Fail closed on digest mismatch / auth failure / gateway unavailable (with clear operator errors)
- Remain offline-independent for already-local images and offline-bundle updates

## Server responsibilities (internal — not in this repo)

- Offline ticket verification, OCI proxy, upstream Hub auth, rate limits, service health
- Dockerfile / Compose / install scripts / Nginx / host secrets

Do not re-publish server implementation into `Soviez/soviez-deploy`.
