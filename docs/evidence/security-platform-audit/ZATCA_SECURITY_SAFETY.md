# ZATCA security safety

Saudi e-invoicing packs live under Soviez ERP addons. Future security remediation **must not** mutate:
- invoice UUIDs, hashes, signed XML, l10n_sa_invoice_signature, chain index, CCSID/PCSID, EDI history, certificates, journals, sequences.

Scanners: read-only SELECT only.
Remediation of malicious technical records must exclude ZATCA business tables from write paths.
Risk if naive “clean DB” scripts touch accounting — **OPERATOR decision + dry-run**.
