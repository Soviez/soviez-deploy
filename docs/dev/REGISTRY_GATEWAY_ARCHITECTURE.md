# Registry Gateway architecture (public summary)

OSS-first: the Gateway speaks Docker Registry HTTP API V2 and proxies to upstream (Docker Hub by default). Soviez layer = ticket verify, scope enforcement, audit, rate limit — operated by Soviez, **not** shipped in the customer deploy repository.

| Role | Path |
|------|------|
| Public client consumer | `src/registry/`, `src/api/registry_client.sh` in `Soviez/soviez-deploy` |
| Internal Gateway package | `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway` (local canonical; no private Git remote yet) |

See `docs/dev/REGISTRY_GATEWAY.md` and `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md` for the client/protocol contract.
