# Migration Domain Preparation

After Phase 17 pairing and readiness, prepare the migration domain **without moving data**.

1. Ensure the migration pair is trusted and readiness is PASS (or accepted WARNING).
2. Create a domain plan: `sudo soviez.sh --migration-domain-plan <pair-id>`
3. Default hostname is `migrate.<your-production-domain>`.
4. Review the plan; it never changes Production DNS by itself.
5. Continue with DNS setup, landing, TLS, then routing readiness.
6. Abort domain prep anytime: `sudo soviez.sh --migration-domain-abort <pair-id>`

Streaming migration and Production cutover are later phases (not enabled here).
