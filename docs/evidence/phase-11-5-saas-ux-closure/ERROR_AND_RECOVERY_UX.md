# Error and Recovery UX — Phase 11.5

**Evidence Date:** July 30, 2026  
**Preview Environment:** `http://127.0.0.1:3011/login?preview=1`

## Error Classification System

### Customer-Facing Errors
All customer-visible errors have structured denial codes with clear recovery paths.

**Implementation:** `src/lib/preview/demo-data.ts` — Complete error taxonomy

| Error Code | Trigger Scenario | Impact Scope | Recovery Complexity |
|------------|------------------|--------------|-------------------|
| `STAGE_ENTITLEMENT_EXPIRED` | Stage License subscription ended | New stage creation only | Simple — Renew subscription |
| `DEVICE_AUTH_REQUIRED` | Server not authorized with Device | Connected operations blocked | Medium — Device authorization flow |
| `DEVICE_REVOKED` | Admin revoked device access | All server operations blocked | Medium — Reauthorization required |
| `OPERATION_AUTHORIZATION_FAILED` | Policy/binding violation | Specific operation failed | Complex — Review bindings |
| `MONTHLY_NEW_SALES_DISABLED` | Attempt to buy retired product | Checkout blocked | Simple — Choose Annual Support |
| `CROSS_ACCOUNT_DENIED` | Access another customer's data | Resource access denied | Simple — Return to own account |

## Error UX Structure

### Standard Error Display Format
Each error follows consistent UX pattern:

1. **Title** — Clear, non-technical error summary
2. **Explanation** — What happened and why
3. **Impact** — What is affected vs. what still works
4. **Next Action** — Specific steps to resolve
5. **Navigation** — Direct link to resolution area

### Example: Stage Entitlement Expired

```typescript
STAGE_ENTITLEMENT_EXPIRED: {
  code: "STAGE_ENTITLEMENT_EXPIRED",
  title: "Stage License expired", // Clear title
  explanation: "Your Stage License for this exact License is no longer active, so new Stage creation is blocked.", // What & why
  impact: "Existing Stages keep running. List, start, stop, backup, and drop remain available on the server.", // Scope of impact
  nextAction: "Renew or reactivate Stage License for this License, then retry create.", // Recovery path
  href: "/dashboard/licenses", // Direct navigation
}
```

## Recovery Flow Implementation

### 1. License-Related Recovery
**Entry Points:**
- License detail page (`/dashboard/licenses/[id]`)
- Dashboard license cards with status indicators

**Recovery Flows:**
- **Manual Activation** — License activation pending acknowledgment
- **Support Renewal** — Annual Support purchase flow
- **Stage License Renewal** — Stage subscription reactivation

**UX Elements:**
- Status badges (Active/Expired/Pending)
- Action buttons (Activate/Renew/Purchase)
- Progress indicators during operations

### 2. Device Authorization Recovery
**Entry Points:**
- Servers page (`/dashboard/servers`)
- Device status indicators throughout app

**Recovery Flows:**
- **Initial Authorization** — First-time device connection
- **Reauthorization** — Restore revoked device access
- **Connection Repair** — Fix credential/network issues

**UX Elements:**
- Device status badges (Connected/Revoked/Reauth Required)
- Authorization buttons and flows
- Fingerprint confirmation dialogs

### 3. Operation Recovery
**Entry Points:**
- Operations page (`/dashboard/operations`)
- Operation status throughout app

**Recovery Flows:**
- **Retry Failed Operations** — Automatically retryable failures
- **Manual Recovery** — CLI-assisted recovery guidance
- **Policy Resolution** — Binding/domain issue resolution

**UX Elements:**
- Operation status indicators (Completed/Failed/Recovery Required)
- Retry buttons where applicable
- Recovery guidance with CLI instructions

### 4. Purchase/Billing Recovery
**Entry Points:**
- Billing page (`/dashboard/billing`)
- Purchase error messages

**Recovery Flows:**
- **Product Substitution** — Monthly Support → Annual Support
- **Payment Resolution** — Failed payment recovery
- **Account Access** — Cross-account denial recovery

**UX Elements:**
- Clear product alternatives presented
- Payment retry mechanisms
- Account boundary enforcement with helpful redirects

## Error Prevention

### Proactive Status Display
**Implementation:** Status indicators throughout app prevent errors before they occur

1. **License Health** — Expiration warnings and status
2. **Device Connection** — Real-time authorization status
3. **Entitlement Visibility** — Clear capability boundaries
4. **Operation Monitoring** — Progress and failure tracking

### Context-Aware Warnings
**Examples:**
- Stage creation disabled when Stage License expired
- Device operations blocked when authorization required  
- Purchase redirects when product unavailable
- Cross-account access prevented with clear messaging

## Recovery Success Metrics

### Customer Self-Service Rate
- **Device Reauthorization** — % completed without support intervention
- **License Activation** — % manual activations completed successfully
- **Operation Retry** — % failed operations successfully retried
- **Purchase Recovery** — % customers who complete alternative purchases

### Error Resolution Time
- **Simple Errors** (CROSS_ACCOUNT_DENIED) — Immediate redirect
- **Medium Errors** (DEVICE_AUTH_REQUIRED) — < 5 minutes to resolution
- **Complex Errors** (OPERATION_AUTHORIZATION_FAILED) — < 30 minutes with guidance

### Error Recurrence Prevention
- **Policy Education** — Customers learn from error explanations
- **Status Monitoring** — Proactive status prevents repeat errors
- **Flow Improvement** — Error patterns drive UX improvements

## Error Accessibility

### Screen Reader Support
- **Error announcements** — Errors announced to screen readers
- **Recovery navigation** — Clear ARIA labels on recovery actions
- **Status communication** — Status changes properly announced

### Visual Design
- **Color-independent** — Status not indicated by color alone
- **Clear hierarchy** — Error information properly structured
- **Actionable elements** — Recovery actions clearly highlighted

## Error Testing

### Automated Error Testing
**Location:** `src/lib/preview/phase115.browser.test.ts`
- Tests all error scenarios in isolated preview environment
- Validates error message accuracy
- Confirms recovery path accessibility

### Manual Error Validation
**Process:** Preview environment allows manual validation of:
- Error message clarity
- Recovery flow usability
- Navigation accuracy
- Mobile error experience

### Edge Case Coverage
- **Simultaneous errors** — Multiple error conditions
- **Partial failures** — Some operations succeed, others fail
- **Recovery interruption** — What happens if recovery is interrupted
- **Cross-device consistency** — Errors display consistently across devices

## Error Documentation

### Customer-Facing Error Help
**Integration:** Error messages link to relevant help documentation
- License management guides
- Device authorization instructions
- Operation troubleshooting
- Billing and purchase assistance

### Internal Error Tracking
**Implementation:** Error codes enable:
- Customer support quick resolution
- Error pattern analysis
- UX improvement prioritization
- System reliability monitoring

## Phase 11.5 Error UX Validation

### Error Coverage Assessment
✅ **Complete Error Taxonomy** — All customer error scenarios covered  
✅ **Structured Error Format** — Consistent title/explanation/impact/action pattern  
✅ **Clear Recovery Paths** — Every error has actionable resolution steps  
✅ **Navigation Integration** — Direct links to resolution areas  
✅ **Prevention Elements** — Proactive status prevents errors when possible

### Recovery Flow Validation
✅ **License Recovery** — Manual activation, renewal flows complete  
✅ **Device Recovery** — Authorization, reauthorization flows complete  
✅ **Operation Recovery** — Retry, manual recovery flows complete  
✅ **Purchase Recovery** — Alternative products, payment flows complete  
✅ **Account Recovery** — Cross-account boundary enforcement complete

### User Experience Quality
✅ **Error Clarity** — Non-technical, actionable error messages  
✅ **Recovery Efficiency** — Direct paths to resolution  
✅ **Error Prevention** — Proactive status display reduces errors  
✅ **Accessibility** — Screen reader compatible error handling  
✅ **Mobile Experience** — Error/recovery flows work on mobile devices

**Error & Recovery UX Status:** COMPLETE — All customer error scenarios have clear, tested recovery paths