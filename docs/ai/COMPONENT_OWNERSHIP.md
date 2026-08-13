# AI Component Ownership

Mirror of `docs/dev/COMPONENT_OWNERSHIP.md`.

**Never implement a second:** update engine, backup engine, migration engine, entitlement engine, DB scanner, firewall manager, quarantine engine.

Extend the owning `src/` module after reading it.
