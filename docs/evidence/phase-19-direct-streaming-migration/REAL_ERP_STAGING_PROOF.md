# REAL_ERP_STAGING_PROOF.md

- Image: `soviez/erp:p15-v15-labeled` (source-compatible labeled candidate)
- Real container process; restored payload DB + clean ERP DB for HTTP
- Transferred filestore/addons/config wiring
- License Guard enabled; migration staging identity; `permanent_slot=false`
- Internal network only (`soviez-p19-stg-*`); no public Production domain publish
- Probe: `/web/login` → HTTP **200** (`test_phase19_real_mtls_e2e.sh`)
- Mode recorded: `real_soviez_erp` (fixture HTML fails certification)
- Exact cleanup removes operation-owned ERP container + staging network
