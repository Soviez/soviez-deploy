# Firewall architecture audit

## Current (ERP installer)
- Installs/enables UFW; allow OpenSSH, 80, 443
- Fail2Ban for sshd + nginx
- No explicit nftables/iptables flush observed in normal path
- No DOCKER-USER chain
- Cloudflare mode can refresh allowlists from live Cloudflare IP lists

## Risks
- Docker published ports bypass classic UFW “deny incoming”
- Docker restart / firewall restart interaction not validated as a certification gate
- APT lock healer may stop unattended-upgrades during install

## Preserve matrix (current code intent)
| Path | Intent |
|------|--------|
| Nginx→Odoo | localhost proxy |
| Odoo→PG | docker DNS on bridge |
| Host→Internet | not restricted by UFW outbound default |
| DNS | host/container resolver — not specially hardened |

Future: DOCKER-USER + loopback Odoo publish + restart regression tests.
