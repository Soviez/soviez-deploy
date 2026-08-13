# Compatibility impact

| Control | Odoo Ent/Com | ZATCA | wkhtmltopdf | Nginx/CF | Docker/PG | Stage/Update/Migration | License/Offline | Webmin hosts |
|---------|--------------|-------|-------------|----------|-----------|------------------------|-----------------|--------------|
| PG least privilege | Need CREATEDB alternative or pre-create DB | None if RO | None | None | Requires provision change | Stage must match | Offline OK | N/A |
| Loopback Odoo port | OK if Nginx local | OK | PDF still local | Required | Restart containers | Stage OK | OK | N/A |
| DOCKER-USER | OK | OK | DNS must pass | OK | Critical | Update tests | OK | Careful |
| Quarantine egress | Breaks live ZATCA until accept | Intentional | May block CDN fonts | OK | OK | Required | Air-gap natural | N/A |
| DB scanner RO | OK | Must not write | OK | OK | OK | OK | OK | OK |
| AIDE/YARA | OK | OK | OK | OK | Disk | OK | Bundle rules | OK |
