# Current State (Authoritative)

```text
Engineering = 100% COMPLETE
Phase 25 = PASS — FINAL CERTIFICATION COMPLETE
Post-cert discrepancy closure = PASS
Security Platform = CERTIFIED
Official Documentation = CANONICAL / CONTRACT-ALIGNED
Canonical contract = docs/SOVIEZ_SH_PRODUCT_CONTRACT.md
Installer = 0.24.6.3-platform-cli
SHA256 = 43de932f2be866f245f2b0b694112c93e811054cd2ccd13fec21df0977897781
Release Readiness = READY_WITH_OWNER_DECISIONS
Release Authorization = NOT AUTHORIZED
Artifact Publication = NOT PUBLISHED
Production Rollout = NOT AUTHORIZED
Phase 11.5 = FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED
```

## Post-cert decisions

- `--merge-in` = **NOT_SUPPORTED** (Case B; use `--migration-*`)
- WebSocket topology = **adaptive** (`workers=0` → `:8069`; multi-worker → `:8069` + `:8072`) — see `docs/SOVIEZ_SH_PRODUCT_CONTRACT.md` §9
- `/longpolling` = **COMPATIBILITY_ROUTED**
- Stage `proxy_mode=True` required
- P21 upstream = resolved host loopback (not blind public 8069)
- Phase-12 SSL template = SUPPORTED_RUNTIME with WS (`phase12-ws1`)
