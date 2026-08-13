# GITIGNORE_AUDIT

## soviez-sh
**`.gitignore` is MISSING** — **BLOCKS_PUBLISH** until added.

Required entries (minimum):
```
.tmp/
.tmp.*
.DS_Store
node_modules/
__pycache__/
*.pyc
.keys.json
/keys.json
/ticket.token
/offline-package.json
.env
.env.*
*.dump
.playwright-browsers/
```

Also ensure `dist/*.sh` policy is intentional (recommend tracking `dist/soviez.sh` + sha256).

## Soviez ERP / soviez-deploy / soviez-saas
Existing ignores present; saas already ignores `.env` / `.env*.local` / `.env.live` / `.env.production`.  
ERP should ensure `venv/` ignored if not already (dirty venv suggests tracking leak historically — do not add venv files).

## Recommendation
Add soviez-sh `.gitignore` **before** any initial commit. Do not apply cleanup deletes in this audit.
