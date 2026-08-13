# STAGE_PROXY_MODE_AUDIT

Defect: ensure_stage_soviez_conf omitted proxy_mode.
Fix: proxy_mode = True in Soviez ERP and soviez-deploy (byte-aligned intent).
Assert: soviez_ws_assert_odoo_conf + WS-003*
