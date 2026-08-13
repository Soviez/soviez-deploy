# OFFLINE_BUNDLE_DEFINITION

```
bundle/
  manifest.json
  manifest.sig
  authorization.json
  authorization.sig
  compatibility/
  images/          # OCI layout
  addons/
  migrations/
  metadata/
  checksums/
  trust/           # public roots only
  docs/
```

Deterministic. No customer DB/filestore/secrets/Registry tokens.
