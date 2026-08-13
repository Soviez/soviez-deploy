# PUBLISH_ORDER

Safest order (do not execute in this audit):

1. **Hygiene**: add soviez-sh `.gitignore`; confirm secrets untracked
2. **soviez-saas**: schema 078–090 + control-plane APIs → deploy to **staging/sandbox** first, then `main` when green
3. **Container image(s)** / Registry metadata if new digests required for sim (if already current, skip)
4. **Soviez ERP `soviez.sh` + soviez-deploy `soviez.sh`** atomically (same SHA)
5. **soviez-sh** initial commit(s) including `dist/soviez.sh` + docs + tests (+ evidence per policy)
6. **Documentation** included with soviez-sh (already)
7. **Smoke**: docs_validate, secret_scan, wizard hash, installer→SaaS staging auth

### Why this order
New installer Stage/migration/offline/registry flows **require** SaaS migrations/APIs first. Wizards and modular installer must land together for WS/proxy_mode parity.
