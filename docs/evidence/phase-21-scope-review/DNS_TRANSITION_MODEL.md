# DNS_TRANSITION_MODEL.md

## Principles

- **Provider-neutral:** No SaaS DNS relay; no mandatory cloud API.
- **Manual-first:** Canonical path is signed instruction document for operator execution **out of band**.
- **Local adapters:** Mock (tests) and optional live adapters (Route53, Cloudflare, bind, etc.) run **on installer host** with operator-supplied credentials — never documented with secrets in evidence.
- **Observation, not mutation:** Installer verifies propagation via public resolvers; does not imply automated Production record change in scope review docs.

## Inputs

- Phase 18 domain plan (Production FQDN, expected destination target).
- Phase 18 DNS ownership proof (TXT challenge) — prerequisite, not substitute.
- Destination Production route + TLS ready (Option C step 1–2).

## Instruction artifact (recommended schema)

```json
{
  "schema": "soviez.migration_dns_cutover_instruction.v1",
  "authorization_id": "...",
  "production_fqdn": "erp.example.com",
  "record_type": "A",
  "previous_target": "<source-public-ip>",
  "new_target": "<destination-public-ip>",
  "ttl_recommendation_seconds": 300,
  "optional_aaaa": "...",
  "verification_queries": ["erp.example.com A", "..."],
  "rollback_previous_target": "<source-public-ip>"
}
```

## Verification epochs

| Epoch | Check |
|-------|-------|
| Pre-switch | Production DNS resolves to source (baseline capture) |
| Post-switch (operator attestation) | Operator confirms change submitted |
| Propagation | Multi-resolver observation; majority policy (OD-09) |
| Health-bound | Public health on FQDN → must hit destination |

## Flags

- `production_dns_changed=true` set at operator attestation or propagation confirm (OD-10).
- Distinct from `traffic_cutover_started` — DNS may change before traffic_owner if source in maintenance.

## Rollback DNS

Within rollback window: instruction emits **reverse** record set to previous target. After meaningful destination writes, DNS-only rollback → **Needs Action** / reverse-migration (see `ROLLBACK_MODEL.md`).

## Unsafe patterns (forbidden)

- Fixture-only provider for live Production (inventory **U**).
- Legacy `--change-domain` implicit DNS assumption.
- SaaS-hosted DNS mutation API as required path.

## OWNER DECISION REQUIRED

**OD-08:** Minimum propagation observation duration before health gate?

**Recommendation:** **5 minutes** after operator attestation with multi-resolver majority.

**OD-09:** Propagation majority rule (e.g. 3/5 public resolvers)?

**Recommendation:** **3/5** resolvers agree on destination target.

**OD-10:** Set `production_dns_changed` at operator attestation vs propagation confirm?

**Recommendation:** **Operator attestation** (honest limit: propagation may lag).
