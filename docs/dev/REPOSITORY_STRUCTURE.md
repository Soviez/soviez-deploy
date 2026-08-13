# Repository Structure

```text
soviez-deploy/   # PUBLIC client-side lifecycle repository ONLY
  src/           modular client implementation
  build/         assemble.sh → dist/soviez.sh
  dist/          certified artifact
  tests/         unit/integration/security/final_certification
  docs/user|dev|ai|security|evidence
  VERSION
  PROJECT_STATE.md
  PRODUCT_CONSTITUTION.md
```

Key `src/` owners: `cli/`, `commands/`, `operations|ops/`, `update/`, `stage/`, `backup/`, `restore/`, `migration/`, `security/`, `offline_*`, `nginx/`, `database/`, `docker/`, `ssl/`, `entitlement/`, `registry/` (client consumer).

**Not published here:** Registry Gateway server package (canonical local: `soviez-registry-gateway/`).
