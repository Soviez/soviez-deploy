# Release catalog — Phase 7

## Design principles

1. **Digest-first** — `manifest_digest` is the only authoritative image reference.
2. **Tags are display-only** — `display_tag` and `release_version` are human-readable; never used for pull authorization.
3. **Status gate** — only `approved` and `published` releases resolve for pull.
4. **Architecture binding** — one catalog row per `(product, version, channel, architecture)`.
5. **Repository allowlist** — `soviez/soviez-erp` enforced in service layer.

## Status lifecycle

```
draft → candidate → approved → published
                              ↘ withdrawn
                              ↘ revoked
```

| Status | Resolve behavior |
|--------|------------------|
| `draft`, `candidate` | `RELEASE_NOT_APPROVED` |
| `approved`, `published` | Allowed |
| `withdrawn` | `RELEASE_WITHDRAWN` |
| `revoked` | `RELEASE_REVOKED` |

## Resolve selection rules

| Input | Selection |
|-------|-----------|
| `release_id` | Exact row |
| `release_version` + `channel` | Exact match |
| Neither | Latest `published_at` in channel among approved/published |

## CI integration (prep)

Workflow: `Soviez ERP/.github/workflows/phase7-registry-release-metadata.prep.yml`

- Builds immutable version tag (not `:latest` authority)
- Captures manifest digest via `docker buildx imagetools inspect`
- Emits `artifacts/release-candidate.json` with `status: candidate`
- Optional signed manifest when secrets provisioned
- Exports OCI tar for offline bundle input
- **Does not** auto-publish to customer catalog or change Hub visibility

## Signed manifest caching

On first resolve, SaaS may sign and persist `signed_manifest_json` + `signer_key_id` on the release row.

## Tests

- Unit: `releaseStatusDenial`, repository allowlist, architecture normalization
- DB: published release insert + resolve path in harness
