# Repository layout

```
soviez-deploy/          # PUBLIC — customer/client deployment only
  PRODUCT_CONSTITUTION.md
  PROJECT_STATE.md
  README.md
  docs/{ai,user,dev,security,evidence}/
  src/{commands,lib,entitlement,registry,ops,...}/
  schemas/
  scripts/
  tests/
  dist/                 # generated client artifact only
```

**Boundary:** Internal Soviez services (Registry Gateway server, control-plane, etc.) must not live in this repository.

Canonical Gateway package (internal): `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway`
