# Source Credential Disposition Model

Handle: SMTP, payment, webhook secrets, external API tokens, OAuth refresh, cloud storage, DNS provider, Registry, monitoring, backup credentials.

## Allowed actions

disable · revoke · rotate · quarantine · export encrypted · retain temporarily · delete later

**Do not silently destroy credentials.**

## Recommended

1. Disable source integrations  
2. Verify destination owns active credentials where appropriate  
3. Create credential disposition inventory  
4. Mark each: `retained` | `rotated` | `revoked` | `quarantined` | `deferred`  
5. Incomplete disposition → Phase 22 readiness WARNING/BLOCKED  
6. No credential deletion without explicit later policy  

No secrets in argv, logs, or cleartext manifests.
