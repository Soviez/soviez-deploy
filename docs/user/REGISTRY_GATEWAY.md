# Registry Gateway (customer / operator view)

Canonical hostname: `registry.soviez.com` (staging: `registry-staging.soviez.com`).

## What it does (from the client)

When Soviez.sh performs a **connected** private image pull, it:

1. Obtains a short-lived Registry Ticket from Soviez SaaS (entitlement-gated).
2. Exchanges that ticket at the Registry Gateway for temporary Docker Registry credentials.
3. Pulls the authorized image using a temporary `DOCKER_CONFIG` (never `~/.docker/config.json`).
4. Enforces the **exact digest** from the release/target metadata.
5. Logs out and deletes the temporary Docker config.

Customers never receive upstream Docker Hub credentials.

## Connected vs offline

- Connected update / image pull → Registry Gateway (client consumption above)
- Offline update → signed offline bundle (Gateway not used)

## Expected client-visible behavior

- Gateway URL is configurable via `SOVIEZ_REGISTRY_GATEWAY_URL` (default `https://registry.soviez.com`).
- Failures surface as installer/API errors (auth, pull, digest mismatch, gateway unavailable).
- After images are local, running ERP does **not** require continuous Gateway availability.

## What is not in this repository

Gateway **server** installation, Compose, Nginx, upstream Hub credentials, and internal operations remain **internal Soviez infrastructure** and are not published in `Soviez/soviez-deploy`.
