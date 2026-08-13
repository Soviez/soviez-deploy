# Abort Migration Domain Preparation

Run: `sudo soviez.sh --migration-domain-abort <pair-id>`

This removes destination landing/TLS/challenge state created for domain preparation.

It does **not**:

- Delete DNS records you created (remove those yourself if desired)
- Stop or change Production
- Transfer or delete business data
- Consume a Migration Token

Your source system remains active.
