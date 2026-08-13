# Registry Gateway invariants (AI)

- Never return upstream credentials to clients
- Pull-only; deny push/delete/catalog
- Ticket bind: license/account, device, repo, digest, session
- Temporary docker auth only; cleanup after pull
- Offline independent of Gateway
- Running ERP independent of Gateway outage
