# Real ERP Upgrade E2E

## Method
Inside candidate container:
```text
python3 soviez-bin -c candidate.conf -d <exact_db> \
  -i/-u base,web,local_license_guard --stop-after-init
```
Disposable migration secret via env (test-only; not production).

## Validation
- Upgrade log written under operation dir
- HTTP GET candidate `/web/login` → success recorded in `http_validation.json`
- Connected update completes with `UPDATE_COMPLETED`
- Production `current_digest` advances only after validated switch

## Result
PASS — real module install/upgrade + HTTP login validation on candidate.
