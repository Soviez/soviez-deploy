# PERFORMANCE_AND_IMPACT

- Domain prep is metadata/control-plane only — no DB/filestore copy
- Source remains serving Production traffic
- Temporary destination landing/nginx/TLS only on mig FQDN
- Challenge/readiness TTLs bound resource lifetime (30m / 24h)
