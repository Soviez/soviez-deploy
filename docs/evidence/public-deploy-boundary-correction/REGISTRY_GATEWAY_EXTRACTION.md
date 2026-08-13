# REGISTRY_GATEWAY_EXTRACTION

## Before

`Soviez/soviez-deploy/services/registry-gateway/` — full server package (incorrectly public).

## After

- Public path: **ABSENT**
- Internal canonical: `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway`
- Client retained: `src/registry/`, `src/api/registry_client.sh`
- Byte-sync-to-public rule: **REMOVED** (see internal `CANONICAL_SOURCE.md`)
- Duplicate independently maintained public copy: **0**
- Note: local `soviez-sh/services/registry-gateway/` may still exist as a legacy mirror outside this public correction; canonical ownership is the local ops folder only.
