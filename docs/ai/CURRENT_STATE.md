# Current State (Authoritative)

```text
Engineering = 100% COMPLETE
Phase 25 = PASS — FINAL CERTIFICATION COMPLETE
Post-cert discrepancy closure = PASS
Security Platform = CERTIFIED
Official Documentation = CANONICAL / CODE-SYNCHRONIZED
Installer = 0.24.5.3-registry-gateway
SHA256 = 68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460
Release Readiness = READY_WITH_OWNER_DECISIONS
Release Authorization = NOT AUTHORIZED
Artifact Publication = NOT PUBLISHED
Production Rollout = NOT AUTHORIZED
Phase 11.5 = FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED
```

## Post-cert decisions

- `--merge-in` = **NOT_SUPPORTED** (Case B; use `--migration-*`)
- WebSocket topology = **workers=0 → :8069** (SUPPORTED_AND_CERTIFIED)
- `workers>0` / gevent publish = **NOT_SUPPORTED**
- `/longpolling` = **COMPATIBILITY_ROUTED**
- Stage `proxy_mode=True` required
- P21 upstream = resolved host loopback (not blind public 8069)
- Phase-12 SSL template = SUPPORTED_RUNTIME with WS (`phase12-ws1`)
