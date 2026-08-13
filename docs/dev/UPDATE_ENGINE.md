# Update Engine

Owner: `src/update/engine.sh` (`soviez_update_run`).

Flow: apt wait → entitlement → exact release → backup → candidate → upgrade → S5 validate (when enforced/prod) → switch → complete/rollback.

S5 gate: `src/security/update_safety/gate.sh`.
