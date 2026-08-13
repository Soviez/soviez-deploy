# Webmin / Virtualmin audit

Current logic: **none** for detect/report of Webmin/Virtualmin/port 10000.

Future postures (detect + report, never blind remove):
1. Trusted IP allowlist
2. VPN-only
3. Zero-trust access layer
4. Explicit owner-accepted public exposure (documented exception)

Default recommendation: detect → HIGH finding if public :10000 without allowlist.
