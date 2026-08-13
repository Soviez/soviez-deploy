# PDF Reporting

## Runtime

Production ERP images used in certification include **wkhtmltopdf** (S6 real PDF path produced `%PDF-`).

## Update health

S5/S6 update safety can validate PDF generation after updates. Injected PDF failures fail the gate.

## Troubleshooting 504

| Cause | Action |
|-------|--------|
| wkhtmltopdf missing in image | Use certified ERP image with wkhtmltopdf |
| Report timeout | Check Nginx/proxy timeouts; worker load |
| Network asset fetch blocked | Review outbound policy for report assets |

Do not expose Odoo publicly to "fix" PDF.
