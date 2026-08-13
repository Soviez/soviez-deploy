# BASELINE — Phase 8 New Connected Activation

**Date:** 2026-07-30T01:21:36Z (updated)  
**Prior phase verdict:** Phase 7 PASS — 31% cumulative  
**Phase 8 authorization:** Authorized for modular installer implementation  
**Certification host:** darwin 25.5.0 (local dev)

## Repository state at Phase 8 start

```
saas=2f2f13c655ac42aa976764db56d939bf60a40094 dirty=32
date=2026-07-30T01:01:36Z
```

## Phase 8 scope baseline

| Component | Pre-Phase-8 | Post-Phase-8 |
|-----------|-------------|--------------|
| `soviez-sh/src/` | Empty/scaffold | 36 modular bash modules |
| `dist/soviez.sh` | N/A | Assembled v0.8.0-phase8 |
| `--new` command | Planned | Implemented |
| `--reattach` | Planned | Implemented |
| Device auth wiring | APIs only | Wired in `--new` |
| Slot reservation wiring | APIs only | Wired in `--new` |
| Registry pull wiring | Gateway only | Wired in `--new` |
| ORM activation | Planned | Stub + official path code |
| `local_license_guard` | Unchanged | **Still unchanged** |

## Acceptance gate prerequisites (from master plan)

- [x] Modular `src/` with `build/assemble.sh`
- [x] Consent before connected egress
- [x] Auto + manual activation paths
- [x] Disconnect/resume
- [x] Secret handling (no key in argv/logs)
- [x] Installer test suite
- [ ] Full disposable Odoo ERP container ORM E2E — **NOT RUN** (PARTIAL reason)

## Tooling baseline

| Tool | Availability |
|------|--------------|
| `bash -n` | Available — PASS |
| ShellCheck | **Unavailable** on this host |
| Docker (real) | Not used in certification (test mode stubs) |
| Python 3 | Available — mock SaaS + guard cert |

## Weight baseline

Phase 8 weight = 7. On full PASS would reach 38%. PARTIAL: weight not awarded; stays 31%.
