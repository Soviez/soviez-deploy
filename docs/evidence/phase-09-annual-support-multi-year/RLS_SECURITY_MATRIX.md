# RLS_SECURITY_MATRIX — Phase 9

## Table policies

| Table | anon | authenticated | service_role |
|-------|------|---------------|--------------|
| support_commercial_settings | ❌ no grant | ✅ SELECT all rows | ✅ ALL |
| support_term_discount_rules | ❌ | ✅ SELECT enabled=true only | ✅ ALL |
| support_coverage_periods | ❌ | ✅ SELECT account_id = auth.uid() | ✅ ALL |
| support_coverage_events | ❌ | ✅ SELECT account_id = auth.uid() | ✅ ALL |
| support_annual_quotes | ❌ | ✅ SELECT account_id = auth.uid() | ✅ ALL |

## Mutation paths

All INSERT/UPDATE/DELETE on coverage, quotes, and commercial settings go through **server routes** using `createAdminClient()` (service_role). No client-side mutations.

## RPC exposure

| RPC | Client callable? |
|-----|------------------|
| support_extend_annual_coverage | ❌ service_role only |
| support_reverse_coverage_period | ❌ service_role only |
| support_resolve_annual_coverage | ✅ authenticated (read) |
| support_calculate_prepaid_price_cents | ✅ authenticated |
| support_resolve_term_discount_rule | ❌ service_role (quote path uses admin client) |

## Cross-account isolation

- Quote API: account_id from session user
- Coverage API: license ownership verified before read
- RLS: coverage/quotes filtered by account_id = auth.uid()

## Certified tests

| Test | Result |
|------|--------|
| anon SELECT support_commercial_settings | REJECT (rls_anon PASS) |
| anon SELECT support_term_discount_rules | REJECT (rls_anon PASS) |

## Admin routes

Protected by `requireAdminSession()` — separate from customer RLS.

## Threat considerations

| Threat | Mitigation |
|--------|------------|
| Client extends own coverage | RPC not granted to authenticated |
| Client modifies discount rules | No authenticated write policy |
| Quote price tampering | Server re-validation at checkout |
| Cross-license coverage read | License ownership check + account RLS |
