# Architecture map

## Existing
```
Portal/SaaS ←→ Stripe
     ↓
purchases/licenses/user_addons
     ↓ (human paste)
ERP local_license_guard
Installer (legacy) → Docker Hub :latest → host
```

## Planned
```
soviez-sh modular engine
  ↔ device auth + entitlement APIs + pull sessions (SaaS)
  ↔ local ops state / systemd workers
  ↔ ORM activation only
  ↔ direct server↔server migration streams
```

## Confirmed decision
No SaaS proxy of DB/filestore. No continuous phone-home.
