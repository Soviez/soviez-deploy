# PDF / wkhtmltopdf Report Safety (S5)

Production smoke via `soviez_s5_check_pdf`: prefers real wkhtmltopdf in Odoo container when present; synthetic `%PDF-` path for CI/stock images. Stock `ubuntu:24.04` base without wkhtmltopdf → **N/A** (documented). Inject FAIL must not pass.
