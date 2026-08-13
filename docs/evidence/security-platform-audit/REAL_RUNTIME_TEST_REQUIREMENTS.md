# Real-runtime test requirements

| Test class | Fixture OK? | Real required |
|------------|-------------|---------------|
| Role SUPERUSER/COPY PROGRAM | Partial unit | Real PG |
| Port exposure 5432/8069 | Partial | Real Docker publish + host scan |
| Firewall/Docker restart | No | Real UFW/nft + Docker restart |
| Reboot survive | No | Real reboot |
| Quarantine blocked egress | No | Real network ns/firewall |
| wkhtmltopdf | Partial | Real binary + outbound deps |
| DB IOC scanner detect | Fixture payloads OK | Scanner must not execute |
| HTTPS/Nginx | Partial | Real Nginx TLS |
| Secret hygiene | Fixture | + real log capture |
