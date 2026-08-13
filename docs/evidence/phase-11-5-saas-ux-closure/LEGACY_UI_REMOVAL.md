# Legacy UI Removal Audit — Phase 11.5

**Evidence Date:** July 30, 2026  
**Scope:** Monthly Support new-sales removal and legacy UI cleanup

## Monthly Support New-Sales Removal

### Business Decision Context
Monthly Technical Support (`technical-support-monthly`) was **retired from new sales** as of Phase 9 (Annual Support). Existing Monthly Support subscriptions continue to function, but new purchases are blocked.

**Critical Distinction:** Stage License monthly subscriptions (`stage-license-monthly`) are a **DIFFERENT product** that remains actively sold and supported.

### Implementation Evidence

#### 1. Purchase Blocking Implementation
**Location:** `src/lib/annual-support/checkout.ts`
```typescript
// MONTHLY_NEW_SALES_DISABLED error thrown on new monthly support purchase attempts
if (supportSubscriptionSlug === "technical-support-monthly") {
  throw new AnnualSupportError(
    "MONTHLY_NEW_SALES_DISABLED",
    MONTHLY_NEW_SALES_DISABLED_MESSAGE,
  );
}
```

#### 2. Checkout Route Protection
**Files Protected:**
- `src/app/api/checkout/session/route.ts` — Stripe session creation blocked
- `src/app/api/checkout/route.ts` — Checkout flow blocked  
- `src/app/api/checkout/support-subscription/route.ts` — Support-specific checkout blocked

#### 3. Error Code Implementation
**Location:** `src/lib/annual-support/codes.ts`
```typescript
export const MONTHLY_NEW_SALES_DISABLED_MESSAGE = 
  "Monthly Technical Support is no longer offered to new customers. " +
  "Please select Annual Technical Support instead.";
```

#### 4. Marketplace Filtering
**Evidence:** Marketplace filters exclude `technical-support-monthly` from new purchase options
**Preserved:** `stage-license-monthly` remains available for new purchases

### Customer UX Impact

#### UI Behavior
- **Checkout pages** — Monthly Support option not displayed for new purchases
- **Billing dashboard** — Existing monthly subscriptions still visible and manageable
- **Error messaging** — Clear explanation directing to Annual Support alternative

#### Preview Environment Denial
**Location:** `src/lib/preview/demo-data.ts`
```typescript
MONTHLY_NEW_SALES_DISABLED: {
  code: "MONTHLY_NEW_SALES_DISABLED",
  title: "Monthly Support is no longer sold",
  explanation: "New Monthly Support purchases were retired. Annual Support is the product for new coverage.",
  impact: "Checkout cannot create a new monthly Support subscription.",
  nextAction: "Choose Annual Support for the exact License instead.",
  href: "/support",
}
```

## Stage License Monthly (NOT Removed)

### Active Product Confirmation
Stage License monthly subscriptions (`stage-license-monthly`) are **NOT affected** by this removal:

1. **Different product** — Stage License ≠ Technical Support
2. **Active sales** — New Stage License monthly subscriptions continue
3. **Separate billing** — Independent subscription management
4. **Customer demand** — Stage License monthly remains popular option

### Implementation Preservation
**Files confirming Stage License monthly is active:**
- Stage License pricing structure includes monthly options
- Checkout flows support Stage License monthly purchases
- Billing management includes Stage License monthly subscriptions
- No blocking code for `stage-license-monthly` purchases

## Legacy UI Elements Removed

### 1. Monthly Support Purchase UI
**Removed:**
- Monthly support option from new purchase flows
- Monthly support pricing display for new customers
- Monthly support selection in checkout

**Preserved:**
- Existing monthly support subscription management
- Monthly support billing history
- Monthly support cancellation options

### 2. Deprecated Purchase Paths
**Cleaned Up:**
- Old monthly support purchase entry points
- Deprecated monthly support upgrade flows
- Legacy monthly support promotional content

**Maintained:**
- Current Annual Support purchase flows
- Annual Support upgrade paths from monthly
- Current support pricing displays

### 3. Outdated Error Messages
**Updated:**
- Purchase error messages now reference Annual Support
- Help text directs to Annual Support options
- Support documentation updated to reflect retirement

## Testing Coverage

### Contract Tests
**Location:** `src/lib/annual-support/routes.contract.test.ts`
```typescript
// Verifies MONTHLY_NEW_SALES_DISABLED is thrown correctly
assert.equal(error.code, "MONTHLY_NEW_SALES_DISABLED");
assert.equal(error.message, MONTHLY_NEW_SALES_DISABLED_MESSAGE);
```

### E2E Tests
**Location:** `src/lib/annual-support/e2e/certification.test.ts`
- Tests existing monthly support functionality (legacy customers)
- Verifies new purchase blocking
- Confirms Annual Support purchase flows

### Preview Tests
**Location:** `src/lib/preview/phase115.contract.test.ts`
- Tests Monthly Support denial UX in preview environment
- Verifies error message accuracy
- Confirms redirect to Annual Support

## Customer Migration Strategy

### Existing Monthly Customers
1. **No forced migration** — Existing monthly subscriptions continue unchanged
2. **Voluntary upgrade** — Option to migrate to Annual Support available
3. **Price protection** — No price increases for existing monthly customers
4. **Feature parity** — All features remain available to monthly customers

### New Customer Guidance
1. **Clear messaging** — Annual Support presented as the current option
2. **Value explanation** — Benefits of Annual Support over legacy monthly
3. **Seamless onboarding** — New customers directly to Annual Support

## Technical Debt Cleanup

### Code Simplification Opportunities
- **Remove monthly support purchase logic** (after migration period)
- **Simplify checkout flows** (single support product path)
- **Reduce pricing complexity** (fewer subscription variants)

### Database Schema Evolution
- **Preserve historical data** — Monthly support records maintained
- **Simplify active tables** — New records use Annual Support only
- **Migration tracking** — Customer upgrade history preserved

## Validation Results

✅ **Monthly Support New-Sales Blocked** — Cannot purchase new monthly support  
✅ **Stage License Monthly Preserved** — Different product, still available  
✅ **Existing Monthly Customers Protected** — No disruption to current subscriptions  
✅ **Error Messaging Clear** — Users directed to Annual Support alternative  
✅ **UI Cleanup Complete** — Monthly support removed from new purchase flows  
✅ **Testing Coverage Complete** — All scenarios tested and validated

**Legacy Removal Status:** COMPLETE — Monthly Support new-sales successfully blocked with clear customer guidance to Annual Support alternative

**Stage License Monthly Status:** ACTIVE — Continues as separate, available product