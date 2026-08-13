# Egress security model

Default Production: **observable outbound** (log/monitor), not restrictive allowlist until app inventory complete (ZATCA, SMTP, payments, IAP, apt, CF, License, Registry, backup).

High-security optional: explicit allowlist mode with Stage validation first.
Quarantine mode: blocked egress for restore first-boot.
