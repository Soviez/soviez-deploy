# ROUTING_READINESS_EXPIRY_AND_DRIFT

- TTL: `SOVIEZ_MIG_ROUTING_PLAN_TTL_SECONDS=86400` (24h)
- Drift module: `routing/drift.sh` invalidates on material source/dest/landing/TLS change
- Pair revoke invalidates readiness
