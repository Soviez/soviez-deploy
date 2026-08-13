# Registry Gateway (operator)

**Status:** IMPLEMENTED / INSTALLABLE / TESTED

Canonical hostname: `registry.soviez.com` (staging: `registry-staging.soviez.com`).

## What it does
Bridges SaaS short-lived Registry Tickets to private ERP image pulls. Customers never receive upstream Docker Hub credentials.

## Connected vs offline
- Connected update / image pull → Registry Gateway
- Offline update → signed offline bundle (Gateway not used)

## Install (Soviez-controlled server)
See `services/registry-gateway/docs/INSTALLATION.md` (also published under the deployment repository).

## Health
- `GET /live` — process up
- `GET /ready` — ticket public keys configured

## Sovereignty
Running ERP does **not** require continuous Gateway availability after images are local.
