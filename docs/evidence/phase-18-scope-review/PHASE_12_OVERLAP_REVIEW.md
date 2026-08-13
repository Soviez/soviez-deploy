# PHASE_12_OVERLAP_REVIEW.md

## Phase 12 owns (preserved)

Post-provision certificate **lifecycle** for managed Production and Stage: inventory, monitor, renewal modes, retry/backoff, signed DNS/ACME challenge binding, ACME fixture/provider abstraction, Nginx ownership, atomic promote/rollback, readiness/temporary HTTP, CLI `--ssl-*`.

## Phase 18 must not reimplement as a second lifecycle engine

Phase 18 **reuses** Phase 12 primitives for:

- Certificate storage layout patterns (0600 keys, inventory without private keys)  
- Challenge nonce/expiry/replay/consume/abort  
- Policy: public CA default, self-signed final deny, private CA opt-in, wildcard opt-in  
- Nginx owned-site promote/test/reload/rollback **scoped to migration landing site IDs**  
- Backoff and exact-env locks  

## Phase 18 adds (not Phase 12)

| Concern | Phase 12 | Phase 18 |
|---------|----------|----------|
| Target | Existing Production/Stage env | Exact **migration pair** + destination bootstrap |
| Domain | Current env domain | **Dedicated migration subdomain** (default); not Production cutover |
| Landing | ERP upstream / temp HTTP to ERP | **Neutral maintenance landing** (not ERP) |
| DNS | Challenge for ACME; no provider mutate | Ownership TXT + reachability A/AAAA/CNAME; Try Again; authoritative+public checks |
| Routing | Promote HTTPS for that env | **Routing plan** without Production cutover |
| Source | May renew/repair that env’s cert | **Must not** mutate source Production routing/nginx/cert/DNS |
| Token / pair | N/A | Bound to Phase 17 pair; token still unconsumed |

## Conflict rule

Concurrent Phase 12 renewal for hostname `X` **denies** Phase 18 TLS prepare for the same exact hostname. Migration subdomain `migrate.example.com` does not conflict with Production `example.com` renewal.

## Overlap clarity verdict

**Clear.** Phase 12 = lifecycle of existing managed envs. Phase 18 = migration-domain control plane preparation on destination, bound to a pair, without cutover.
