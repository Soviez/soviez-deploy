# Source Certificate Retention Model

| Topic | Recommended |
|-------|-------------|
| Validity after cutover | Retain through archive verification |
| Source FQDN resolvable | Prefer not publicly routing; FQDN policy OPEN (OD-37) |
| Renewal ownership | Do not auto-renew as Production; policy OPEN (OD-34) |
| Private key | Local, protected; never to SaaS |
| Archive | Public fingerprints + metadata only in manifest |
| Revocation | **Deferred**; not automatic in Phase 22 |
| Host shutdown | Key remains on host/media per inventory |

Future revocation/destruction requires separate authorization (purge/decommission phase).
