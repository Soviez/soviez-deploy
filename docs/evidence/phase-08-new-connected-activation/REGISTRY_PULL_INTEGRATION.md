# REGISTRY_PULL_INTEGRATION — Phase 8

**Clients:** `src/api/registry_client.sh`, `src/registry/manifest_verify.sh`, `src/registry/pull_client.sh`  
**Protocol:** `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`

## API call sequence in `--new`

| Order | Function | Route / action | State after |
|-------|----------|----------------|-------------|
| 1 | `soviez_registry_resolve_release` | `POST /api/installer/registry/releases/resolve` | `release_resolved` |
| 2 | `soviez_manifest_verify` | Local Ed25519 verify | — |
| 3 | `soviez_registry_create_pull_session` | `POST .../pull-sessions` | `image_pull_authorized` |
| 4 | `soviez_pull_client_run` | OCI pull via gateway | `image_pulled` |
| 5 | (implicit complete) | `POST .../complete` | — |

## Digest pinning

Manifest digest verified before pull. Pull client asserts local image matches authorized digest.

Certified log line: `Manifest verified digest=sha256:a4d451ec…` in test output.

## Temp docker config

- Created in `$TMPDIR/soviez-docker-config.*`
- Deleted after pull
- Certified: `test_cleanup_boundaries.sh` — zero leftover config dirs

## Test matrix

| Scenario | Test | Result |
|----------|------|--------|
| Resolve + verify + pull (mock) | `test_new_automatic_path.sh` | PASS |
| Cleanup after pull | `test_cleanup_boundaries.sh` | PASS |
| Digest unit tests | `test_digest.sh` | PASS |

## Sovereignty

- No Hub org token on client
- Pull optional for running ERP
- Device PoP + `private_image_pull` capability required (mock grants in test)

## Live cutover

Docker Hub private visibility change **not** executed in Phase 8 certification.
