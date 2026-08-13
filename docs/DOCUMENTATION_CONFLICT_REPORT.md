# Documentation Conflict Report

## Before canonicalization (material conflicts / drifts)

Approximate material conflicts addressed: **12+**

Examples resolved:
- Stale progress/release language vs Phase 25 100%
- LOCAL_ONLY implied as DR
- Webmin install implication missing never-install statement
- Apt killall language vs wait-or-fail
- `--merge-in` as if implemented
- `--init` attributed to modular CLI
- Public 8069 troubleshooting advice risk
- Nginx "owned templates always have longpolling" overclaim
- Engineering complete conflated with release
- Artifact version/SHA drift in operator docs
- Support expiry stopping ERP (false)
- Stage entitlement expiry deleting Stages (false)

## After canonicalization

```text
Current-behavior unresolved conflicts = 0
```

Documented **AMBIGUITIES** (not conflicts): gevent/workers>0 realtime unverified; Stage proxy_mode parity gap; P21 hardcoded 8069; Phase-12 SSL template lacks WS — called out in WebSocket docs.

## Deprecated treatment

Superseded user fragments → `docs/archive/pre-canonical-user/` with `# Moved` pointers in place.
