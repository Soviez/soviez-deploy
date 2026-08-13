# PHASE24_CANONICAL_OBJECTIVE.md

## Canonical short title
**Security hardening**

## Corrected product title (scope review)
**Security Hardening — Signed-Update Enforcement, Secret Hygiene, Ticket-Replay Consolidation, Registry Lockdown, and Secret-Scan CI**

## Objective (binding)
Close remaining security gaps across the certified installer/SaaS surface without reopening certified architecture:

1. **Remove / prove absence of unsigned self-update** — enforce signed-only update/offline paths; eliminate soft verify and fixture escape hatches outside explicit test mode; sync stale docs.
2. **Key hashing / secret hygiene** — define and implement at-rest handling for activation/license secrets consistent with Sovereignty First (no plaintext abuse; no service-role credentials in installer).
3. **Ticket replay** — certify consolidated replay protection across Stage tickets, offline packages, offline bundles, migration offline packages, DNS challenges — without a second engine.
4. **Registry lockdown** — fail-closed ephemeral credentials; no permanent Docker login; no Registry secrets in bundles; harden soft HOME docker-config checks.
5. **Secret scans CI** — add repository CI secret scanning + keep local `tests/security/*` green.

## Acceptance (master plan)
- Security test suite green (including new Phase 24 suite).
- No service-role **credentials** in `dist/soviez.sh` (clarify: deny-list string may remain if documented).

## Non-goals
See `SCOPE_EXCLUSIONS.md`.
