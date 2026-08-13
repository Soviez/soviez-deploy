# Firewall

## Expected allows

- 22/tcp (SSH)
- 80/tcp (HTTP/ACME)
- 443/tcp (HTTPS)

## Expected denials / containment

- Public 8069 / 8071 / 8072 / 5432
- Docker user-chain drops for forbidden container ports (policy)

## Modes

UFW is used by the Production wizard. Modular S2 firewall helpers also support nftables/firewalld detection without blind global reset.

**Never** disable the firewall as a default troubleshooting step.
