# ERP_PUBLICATION_SCOPE

Remote: `https://github.com/Soviez/soviez-erp.git`  
Current branch: `dev` (= `main` tip locally)  
Target: `main` via PR

## Requires publish? YES — scoped

| Path | Classification | Why |
|------|----------------|-----|
| `soviez.sh` | PUBLISH_REQUIRED_CROSS_REPO | Post-cert Stage `proxy_mode=True`, `workers=0`, `/websocket`→8069, `/longpolling` compatibility, apt-lock safety |

SHA256 of wizard: `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841` (must match soviez-deploy)

## Do NOT publish with this cycle
- `CHANGELOG.md` Partner Subledger / Lugmety entries
- `venv/**`
- Unrelated custom app work
- `.DS_Store`

Dirty count ~138; publishable cycle files: **1**.
