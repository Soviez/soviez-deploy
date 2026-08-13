# Canonical source map — Soviez Registry Gateway

| Role | Path |
|------|------|
| Local ops / installable package (this tree) | `soviez-registry-gateway/` |
| Published path in Soviez/soviez-deploy | `services/registry-gateway/` |
| Application source of truth (this cycle) | Keep `soviez-registry-gateway/` and `soviez-sh/services/registry-gateway/` **byte-synced** |

## Sync rule

During this publication cycle:

1. Treat `soviez-registry-gateway/` as the **canonical installable package** (app + deploy packaging).
2. Keep application and packaging files mirrored into `soviez-sh/services/registry-gateway/` so that tree can be published as `services/registry-gateway/` inside Soviez/soviez-deploy.
3. After any change, sync both directions (or regenerate the publish tree from the ops folder) before tagging a release.
4. Never commit real secrets (`.env`, Hub tokens, private keys).

## Domains

- Production: `registry.soviez.com`
- Staging: `registry-staging.soviez.com`
