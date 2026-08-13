# SIGNED_DNS_CHALLENGE

- TXT name: `_soviez-migration.<migration-fqdn>`
- TTL: 30m (`SOVIEZ_MIG_DNS_CHALLENGE_TTL_SECONDS=1800`)
- Sign/verify via Device key family; replay denied; expiry denied; renew issues new id
- Try-again keeps same challenge id and is idempotent when verified

Unit: PASS
