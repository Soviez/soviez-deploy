# AI Component Ownership

Mirror of `docs/dev/COMPONENT_OWNERSHIP.md`.

**Never implement a second:** update engine, backup engine, migration engine, entitlement engine, DB scanner, firewall manager, quarantine engine.

Extend the owning `src/` module after reading it.

## Repository boundary (binding)

- `Soviez/soviez-deploy` = public **client-side** lifecycle repository only.
- Registry Gateway **server** = internal (`soviez-registry-gateway/`); never publish into this repo.
- Registry **client** remains in `src/registry/` / `src/api/registry_client.sh`.
