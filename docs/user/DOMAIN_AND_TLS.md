# Domain and TLS

## Production domain

- Set at `--new` / `--domain`
- Nginx listens on public IP `:80` / `:443`
- ACME HTTP-01 via Certbot when DNS validates
- Self-signed fallback may remain until Certbot succeeds

## Stage domain

- Mandatory `--stage-domain FQDN` for Stage create / restore-as-stage
- Separate certificate lifecycle from Production

## Cloudflare

Optional edge mode via `SOVIEZ_EDGE_MODE=cloudflare_aop` (not mandatory). See [CLOUDFLARE.md](CLOUDFLARE.md).

## Modular SSL commands

```bash
soviez.sh --ssl-status [environment-id]
soviez.sh --ssl-renew <environment-id>
soviez.sh --ssl-repair <environment-id>
soviez.sh --ssl-policy <environment-id> [automatic|notify_only|manual]
soviez.sh --ssl-try-again <environment-id>
soviez.sh --ssl-abort <environment-id>
```

SSL operations are designed to **never stop ERP** as a side effect of renewal failure.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| TLS error | Cert path, domain DNS, Certbot logs |
| Domain not resolving | DNS A record / Cloudflare proxy |
| HTTP works, HTTPS fails | Certificate install, Nginx ssl listen |
