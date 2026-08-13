# DESTINATION_GO_LIVE_MODEL.md

## Starting posture (Phase 20 PASS)

| Field | Value |
|-------|-------|
| `destination_status` | `production_licensed_pre_cutover` |
| `public_route` | `false` |
| ERP mode | Production internally |
| Integrations | Neutralized |
| Upstream in nginx | DISABLED per routing plan |

## Go-live sequence (Option C)

```text
1. internal_pre_cutover_health     (already Phase 20)
2. production_route_activate       nginx ownership → ERP upstream ON (private verify)
3. production_tls_validate         LE or promoted cert for Production FQDN
4. await_dns_propagation           observation only; no installer DNS mutation in docs
5. public_health_gate              /web/login + smoke suite on Production domain
6. traffic_owner_commit            public_route=true; status → production_licensed_active
7. integration_activation          mail → payment → webhooks (incremental)
8. stage_public_routes             selected Stages only
```

## `production_route_activate`

- Input: Phase 18 routing plan JSON + Phase 12 nginx ownership.
- Promote destination Production server block; `nginx -t` + reload.
- Verify via direct destination access (Host header / operator smoke) **before** public DNS relies on it.
- Rollback: nginx ownership rollback path from Phase 12.

## Status transitions

| Status | Meaning |
|--------|---------|
| `production_licensed_pre_cutover` | Phase 20; internal only |
| `production_route_pending` | Nginx activated; awaiting DNS/health |
| `production_licensed_active` | Public traffic_owner=destination |
| `production_licensed_rollback` | Rollback epoch (transient) |

## Invariants

- Never `public_route=true` while `traffic_owner=source`.
- Never enable outbound mail/payments/webhooks before public health PASS (OD-15).
- Cron: business jobs remain neutralized until post-health activation policy.

## Destination backup

- Phase 20 post-activation backup is rollback prerequisite.
- Recommend fresh backup snapshot after `production_route_activate`, before DNS (OD-06).

## OWNER DECISION REQUIRED

**OD-06:** Mandatory dest backup between route activate and DNS switch?

**Recommendation:** **Yes** — pins rollback point on destination.

**OD-07:** Allow internal admin login on Production domain before DNS switch?

**Recommendation:** **Yes** via Host-header/direct IP smoke only; not customer-facing URL until health gate.
