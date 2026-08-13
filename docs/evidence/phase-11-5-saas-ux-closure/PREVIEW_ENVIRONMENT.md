# Preview Environment — Phase 11.5

**Evidence Date:** July 30, 2026  
**Environment:** Phase 11.5 Isolated SaaS UX Preview

## Preview Environment Specification

### Access Information
- **URL:** `http://127.0.0.1:3011/login?preview=1`
- **Shell:** Original Client Dashboard vertical sidebar (design correction applied — top-nav shell removed)
- **Bind:** `127.0.0.1` only
- **Environment Label / DB name:** `soviez_preview_phase115_isolated`
- **Isolation Mode:** `SOVIEZ_PREVIEW_MODE=1`
- **PID file:** `/tmp/soviez-phase115-preview.pid`
- **Log:** Cursor terminal / Next dev stdout for the running preview job
- **Restart:** `cd soviez-saas && npm run preview:start`
- **Stop:** `cd soviez-saas && npm run preview:stop`

### Demo Credentials
**Customer Access:**
- **Email:** `customer.demo@soviez.preview`
- **Password:** `Preview-Customer-11.5!`
- **Role:** Customer
- **Account ID:** `acct_preview_customer_001`

**Admin Access:**
- **Email:** `admin.demo@soviez.preview` 
- **Password:** `Preview-Admin-11.5!`
- **Role:** Admin
- **Account ID:** `acct_preview_admin_001`

## Environment Control

### Start Preview Environment
```bash
cd soviez-saas
npm run preview:start
```

**Script Location:** `scripts/preview-start.sh`
**Startup Process:**
1. Check for existing preview instance
2. Set isolated environment variables
3. Launch Next.js development server on port 3011
4. Wait for health check confirmation
5. Display access URL and credentials

### Stop Preview Environment  
```bash
cd soviez-saas
npm run preview:stop
```

**Script Location:** `scripts/preview-stop.sh`
**Shutdown Process:**
1. Read PID from `/tmp/soviez-phase115-preview.pid`
2. Gracefully terminate preview process
3. Clean up PID and log files
4. Confirm shutdown completion

### Environment Status Check
**Health Endpoint:** `http://127.0.0.1:3011/api/preview/status`
**Process Management:**
- **PID File:** `/tmp/soviez-phase115-preview.pid`
- **Log File:** `/tmp/soviez-phase115-preview.log` 
- **Port:** 3011 (configurable via `SOVIEZ_PREVIEW_PORT`)

## Isolation Configuration

### Data Isolation
**Database Label:** `soviez_preview_phase115_isolated`
- **No Live Data** — Completely artificial demo data
- **No Production Keys** — Isolated from live Stripe/Supabase
- **No Customer Data** — No real customer information
- **No Device Secrets** — No production device credentials

### Service Isolation
**Disabled Live Services:**
```bash
export NEXT_PUBLIC_SUPABASE_URL="http://127.0.0.1:54321"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="preview-anon-unused"
export SUPABASE_SERVICE_ROLE_KEY="preview-service-unused"
```

### Environment Variables
**Preview-Specific Configuration:**
- `SOVIEZ_PREVIEW_MODE=1` — Enables preview mode functionality
- `SOVIEZ_PREVIEW_SESSION_SECRET` — Isolated session encryption
- `SOVIEZ_PREVIEW_DB_NAME` — Preview database identifier
- **Live Services Disabled** — Stripe, Supabase, registry connections blocked

## Demo Data Structure

### Customer Data (customer.demo@soviez.preview)
**Licenses:**
- **Main Production** (`LIC-…001`) — Active license with Annual Support
- **Warehouse** (`LIC-…002`) — Activation pending, expired support
- **Legacy Site** (`LIC-…003`) — Legacy monthly support (grandfathered)

**Servers:**
- **HQ Production** — Connected, active operations
- **Old Staging Host** — Revoked access status  
- **Warehouse ERP** — Reauthorization required

**Stages:**
- **stagea.example.com** — Certified, active Stage License
- **stageb.example.com** — Certified, active Stage License
- **stage-wh.example.com** — Recovery required, expired entitlement

**Operations:**
- Stage authorization completed
- DNS validation timeout (retryable)
- Manual activation pending
- Offline package export pending

### Admin Data (admin.demo@soviez.preview)
**System Overview:**
- **Devices:** 3 total (various connection states)
- **License Slots:** 5 purchased, 3 used, 2 available, 1 reserved
- **Annual Support Grants:** 2 active grants
- **Stage License Entitlements:** 2 active subscriptions
- **Releases:** 1 approved release awaiting deployment

## Preview UX Features

### Isolated Preview Badge
**Visual Indicator:** "Isolated preview" badge in ProductShellNav
**Implementation:** 
```tsx
{previewBadge ? (
  <span className="me-2 rounded-full border border-amber-700/50 bg-amber-950/40 px-2.5 py-0.5 text-xs text-amber-100">
    Isolated preview
  </span>
) : null}
```

### Preview-Specific Error States
**Error Scenarios Demonstrable:**
- `STAGE_ENTITLEMENT_EXPIRED` — Stage License renewal flow
- `DEVICE_AUTH_REQUIRED` — Device authorization process
- `DEVICE_REVOKED` — Reauthorization workflow  
- `OPERATION_AUTHORIZATION_FAILED` — Operation retry process
- `MONTHLY_NEW_SALES_DISABLED` — Annual Support redirect
- `CROSS_ACCOUNT_DENIED` — Account boundary enforcement

### Complete Customer Journey
**Available Test Flows:**
1. **Dashboard Overview** — License and server status visibility
2. **License Management** — Detail views and activation flows
3. **Server Administration** — Device authorization and management
4. **Stage Operations** — Stage lifecycle and entitlement management
5. **Billing Integration** — Support purchases and subscription management
6. **Operations Monitoring** — SaaS operation tracking and recovery

### Complete Admin Journey  
**Available Test Flows:**
1. **System Overview** — Global statistics and health monitoring
2. **Device Registry** — Cross-customer device management
3. **Capacity Management** — License slot allocation oversight
4. **Support Administration** — Annual Support grant management
5. **Stage Oversight** — Global stage operation monitoring
6. **Release Management** — Software deployment approval

## Preview Environment Security

### Authentication Isolation
- **Preview-Only Credentials** — Cannot access production systems
- **Session Isolation** — Preview sessions isolated from production
- **Demo Data Only** — No real customer or system data accessible
- **Network Isolation** — No connections to live services

### Data Protection
- **No Live Stripe** — Payment processing disabled
- **No Live Supabase** — Database connections isolated
- **No Device Registry** — No real device connections
- **No Customer PII** — No personally identifiable information

### Development Safety
- **Port Isolation** — Runs on dedicated port 3011
- **Process Isolation** — Separate process from development server
- **Environment Separation** — Clear preview mode indicators
- **Clean Shutdown** — Proper process cleanup on shutdown

## Owner Validation Capabilities

### Customer Experience Validation
**Testable Scenarios:**
- Complete customer onboarding simulation
- License activation and management workflows
- Device authorization and server management
- Stage creation and lifecycle management  
- Support ticket integration and billing flows
- Error states and recovery procedures

### Admin Experience Validation
**Testable Scenarios:**
- System health monitoring and dashboard oversight
- Customer support intervention capabilities
- Capacity planning and slot management
- Global operation oversight and intervention
- Release management and approval workflows
- Cross-customer visibility and administration

### Mobile Experience Validation
**Testing Capabilities:**
- Responsive design across all device sizes
- Touch interaction optimization for mobile
- Mobile navigation patterns and usability
- Mobile form interaction and data entry
- Mobile error states and recovery flows

### Accessibility Validation
**Testing Support:**
- Screen reader navigation testing
- Keyboard-only navigation validation
- Color contrast and visual accessibility
- Mobile accessibility testing
- RTL/Arabic interface testing

## Preview Environment Status

### Startup Verification
✅ **Environment Starts** — Clean startup on port 3011  
✅ **Health Check** — API health endpoint responds correctly  
✅ **Authentication** — Demo credentials authenticate successfully  
✅ **Data Loading** — All demo data loads and displays properly  

### Feature Coverage
✅ **Customer Journey** — Complete customer experience testable  
✅ **Admin Journey** — Complete admin experience testable  
✅ **Error States** — All error scenarios demonstrable  
✅ **Recovery Flows** — All recovery workflows accessible  

### Isolation Validation
✅ **Service Isolation** — No live service connections  
✅ **Data Isolation** — No real customer or production data  
✅ **Security Isolation** — Preview credentials isolated from production  
✅ **Process Isolation** — Clean process management and shutdown  

### Owner Readiness
✅ **Complete UX Validation** — Full customer and admin experience available  
✅ **Error Testing** — All error states and recovery flows testable  
✅ **Mobile Testing** — Mobile experience fully accessible  
✅ **Accessibility Testing** — Screen reader and accessibility validation possible  

**Preview Environment Status:** READY FOR OWNER VALIDATION — Complete isolated environment with full Phase 11.5 SaaS UX functionality