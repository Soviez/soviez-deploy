# Migration Domain Plan Protocol

Command: `sudo soviez.sh --migration-domain-plan <pair-id>`  
Show: `sudo soviez.sh --migration-domain-plan-show <plan-id>`

## Rules

- Requires trusted Phase 17 migration pair
- Default strategy: Option A — `migrate.<production-domain>`
- Rejects Production FQDN as migration target; rejects wildcards
- Source domain inspection is **read-only** (no DNS/nginx/cert mutation)
- Plan object signed; expires with routing-plan TTL (24h)
- Authorization flags always: no transfer, no cutover, no token consume, no dest Production activation, no source DNS mutation

## Outputs

Signed `soviez.migration_domain_plan.v1` with expected TXT/reachability records and source inspection snapshot.
