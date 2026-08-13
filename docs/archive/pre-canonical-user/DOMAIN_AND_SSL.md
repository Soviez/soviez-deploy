# Domain and SSL (operator guide)

## Requirements

Production and Stage need a **trusted** certificate. Self-signed is not accepted as final success.

## Temporary HTTP

During DNS/SSL setup the installer may use temporary HTTP. This is **incomplete** — not Production Ready. After HTTPS activates, HTTP redirects to HTTPS.

## Renewal

By default certificates renew automatically starting **30 days** before expiry. Local warnings appear at 30, 14, 7, 3, and 1 day. Renewal failure does **not** stop ERP or delete Stages — status shows Needs Action and repair remains available.

## Commands

```bash
sudo soviez.sh --ssl-status
sudo soviez.sh --ssl-status <environment-id>
sudo soviez.sh --ssl-renew <environment-id>
sudo soviez.sh --ssl-repair <environment-id>
sudo soviez.sh --ssl-policy <environment-id> [automatic|notify_only|manual]
```

## Private CA / wildcard

Private CA and wildcards are optional enterprise features requiring explicit configuration — never silent defaults.

## Privacy

Certificate health checks are local-first. No hidden telemetry or continuous SaaS phone-home for SSL status.
