# PDF_WKHTMLTOPDF_VALIDATION

| Path | Result |
|------|--------|
| Synthetic PDF magic / fixture | **PASS** |
| Inject FAIL (`SOVIEZ_S5_PDF_INJECT_FAIL=1`) | **works (FAIL)** |
| wkhtmltopdf on stock `ubuntu:24.04` base image | **N/A** (binary absent; reason documented) |
| Production Odoo images with wkhtmltopdf | real path used when container available |

Source: `src/security/update_safety/pdf.sh`; test: `test_s5_pdf_smoke.sh`.
