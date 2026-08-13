# SaaS backend final matrix

Revalidate (no frozen UI edits):
- Clean schema migration + upgrade schema
- Entitlement resolution; License/slot/Stage state
- Update authorization; Registry tickets; offline issuance; migration authorization
- Reconciliation; multi-tenant isolation; idempotency
- Security (no service-role to clients; object-level auth)
- Typecheck / lint / build

Deploy to production SaaS = **out of Phase 25** (separate authorization).
