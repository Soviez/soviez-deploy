# ROLLBACK_PLAN

| Component | Rollback |
|-----------|----------|
| soviez-saas app | Redeploy previous Git SHA on hosting |
| SaaS schema | Prefer forward-fix; down-migrations may be unavailable — keep DB snapshot before 078–090 apply |
| ERP wizard | Revert commit of `soviez.sh` on main |
| soviez-deploy wizard | Revert matching `soviez.sh` commit |
| soviez-sh / dist | Pin operators to previous artifact SHA; if first publish, remove release tag / point docs to prior channel |
| Registry image | Retag previous digest as active |
| Offline bundle metadata | Revert SaaS offline bundle rows / prior bundle IDs |

### Schema rollback consideration
Treat 078–090 as **forward-only** unless explicit down SQL exists — snapshot DB before apply.

### Artifact rollback
Distribute prior SHA `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (0.24.5.1-security-s5-corr1) only if rolling back post-cert intentionally.
