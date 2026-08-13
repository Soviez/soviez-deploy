# Security test matrix

| Area | Coverage |
|------|----------|
| Crypto/signing unit | logic.test.ts |
| Boundary flow contracts | service.boundary.test.ts |
| CSRF/route contracts | routes.contract.test.ts |
| Schema/RLS/transitions/replay | e2e/certification.test.ts |
| Cross-account ownership | DB certification |
| Direct client mutation denied | DB certification |
