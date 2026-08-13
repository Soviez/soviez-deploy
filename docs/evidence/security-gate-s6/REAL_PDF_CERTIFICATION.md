# REAL_PDF_CERTIFICATION

## Verdict
**PASS**

## Runtime
- Image: `soviez-erp:18.0.1.01.5-local-release-candidate-pass5`
- Binary: wkhtmltopdf **0.12.6.1**
- Output magic: `%PDF-`
- `soviez_s5_check_pdf` → PASS
- `SOVIEZ_S5_PDF_INJECT_FAIL=1` → FAIL (blocks)
- Synthetic HTML fixture only (no live customer documents)

Runner: `tests/security/s6/test_s6_real_pdf_odoo.sh`
