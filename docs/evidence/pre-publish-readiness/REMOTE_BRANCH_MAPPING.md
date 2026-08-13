# REMOTE_BRANCH_MAPPING

| Repository | Requires Publish? | Remote | Target Branch | Reason |
|------------|------------------:|--------|---------------|--------|
| soviez-sh | YES | **UNCONFIGURED** — owner must create/link GitHub repo | eventual `main` (recommended via release PR branch first) | Canonical installer/platform; entire certified tree |
| Soviez ERP | YES (scoped) | `origin` (`Soviez/soviez-erp`) | `main` (integrate via `dev` → PR → `main`, or PR from dedicated release branch off `dev`) | Dual Production/Stage wizard post-cert corrections |
| soviez-deploy | YES | `origin` (`Soviez/soviez-deploy`) | `main` | Byte-identical dual wizard parity partner |
| soviez-saas | YES (scoped) | `origin` (`agharaafat/sovize`) | `main` (consider `staging` deploy first) | Entitlements, Device, Registry, Stage, migration auth, offline bundles, migrations 078–090 |

### Explicit answers
- **soviez-sh**: no remote today → publication destination **UNKNOWN until owner creates remote**; intended product home is a new/linked canonical GitHub repository (not ERP, not deploy).
- **Soviez ERP**: `https://github.com/Soviez/soviez-erp.git` → `main`.
- **soviez-deploy**: `https://github.com/Soviez/soviez-deploy.git` → `main`.
- **soviez-saas**: `https://github.com/agharaafat/sovize.git` → `main` (staging branch available for pre-prod deploy).
