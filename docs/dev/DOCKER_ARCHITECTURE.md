# Docker Architecture

```text
Host
 ├─ Nginx (host network :80/:443)
 ├─ Docker bridge network(s)
 │   ├─ odoo (8069 published 127.0.0.1:HOST only)
 │   └─ postgres (5432 internal)
 ├─ Stage containers (isolated)
 ├─ Update candidate (ephemeral)
 └─ Quarantine network (restricted)
```

Firewall DOCKER-USER drops forbidden public container ports. Primary containment is loopback publish + no PG publish.
