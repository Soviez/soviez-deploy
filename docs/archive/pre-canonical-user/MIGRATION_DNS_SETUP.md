# Migration DNS Setup

1. Create the challenge: `sudo soviez.sh --migration-dns-challenge <pair-id>`
2. Print instructions: `sudo soviez.sh --migration-dns-instructions <challenge-id>`
3. At your DNS provider, create:
   - **TXT** `_soviez-migration.<migrate-hostname>` with the printed value (TTL ~300)
   - **A/AAAA or CNAME** for `migrate.<production-domain>` pointing at the destination
4. Verify: `sudo soviez.sh --migration-dns-challenge-verify <challenge-id>`
5. If not ready yet: `sudo soviez.sh --migration-dns-try-again <challenge-id>`
6. Challenge expires in **30 minutes** — renew if needed: `--migration-dns-challenge-retry <pair-id>`

Manual DNS is fully supported. Soviez does not delete your DNS records on abort.
