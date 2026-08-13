# Registry Gateway architecture

OSS-first: Gateway speaks Docker Registry HTTP API V2 and proxies to upstream (Docker Hub by default). Soviez layer = ticket verify, scope enforcement, audit, rate limit.

Canonical source (published): `services/registry-gateway/` in `Soviez/soviez-deploy`.
Local ops folder: `soviez-registry-gateway/` (byte-synced).

See also service README and `CANONICAL_SOURCE.md`.
