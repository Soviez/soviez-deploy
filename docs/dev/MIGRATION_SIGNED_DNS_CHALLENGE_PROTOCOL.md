# Migration Signed DNS Challenge Protocol

Commands:

- `sudo soviez.sh --migration-dns-challenge <pair-id>`
- `sudo soviez.sh --migration-dns-challenge-create <pair-id> [--domain-plan PLAN_ID]`
- `sudo soviez.sh --migration-dns-show <challenge-id>`
- `sudo soviez.sh --migration-dns-challenge-verify <challenge-id>`
- `sudo soviez.sh --migration-dns-try-again <challenge-id>`
- `sudo soviez.sh --migration-dns-challenge-retry <pair-id>` (renew)
- `sudo soviez.sh --migration-dns-abort <challenge-id>`
- `sudo soviez.sh --migration-dns-instructions <challenge-id>`

## Record

- **TXT** name: `_soviez-migration.<migration-fqdn>`
- Value: signed challenge material (no system-access secret)
- Challenge TTL: **30 minutes**
- Recommended DNS TTL: **300s**

## Security

- Signed with Device/app key family (Phase 17 trust)
- One-time consumable; replay of verified challenge denied
- Expired challenge denied; renew issues a new challenge id
- Manual DNS is first-class; mock provider adapter used in tests only
