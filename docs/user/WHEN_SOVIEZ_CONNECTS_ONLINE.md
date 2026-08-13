# When Soviez connects online

## Connected operations (today vs planned)

| Operation | Status |
|-----------|--------|
| Browser device authorization (link a server key) | **Available (Phase 5)** |
| License Slot reservation | **Available (Phase 6 foundation)** |
| Private image pull session (digest-pinned) | **Available (Phase 7 + 8 wired in `--new`)** |
| Automatic activation | **Available (Phase 8 — `--new`)** |
| Update / Stage entitlement checks | Planned |
| Migration-token processing | Planned |

## Confirmed rule

Each Cloud connection is started by you (or an operation you approve). Before send, Soviez discloses what metadata will leave the server.

## Authorizing a server

When you approve a device in the portal:

- Your account is linked to that server’s **public key** for future authenticated requests.
- **No business data** is sent.
- **No License Slot** is consumed by authorization alone.
- The ERP is **not activated** by authorization alone.
- Soviez **cannot stop** Production or Stage by this link.
- You can **revoke** the device later under Dashboard → Devices. Revocation blocks future connected SaaS operations only; running ERP keeps running.

## Private image pull (Phase 7)

When an install or update needs to download the Soviez ERP container image through the private registry path:

| What happens | Detail |
|--------------|--------|
| **You start it** | Pull is never automatic background sync. |
| **Entitlement checked** | Your account must have `private_image_pull` capability (commercial grant). |
| **Device verified** | The server proves it holds the authorized device key. |
| **Digest pinned** | You receive an exact `sha256:…` digest — not a mutable `:latest` tag. |
| **Temporary credentials** | A short-lived pull ticket (about 15 minutes). **Not** a permanent Docker Hub password. |
| **Temp Docker config** | The installer uses an isolated `docker --config` directory and deletes it after pull. |
| **No push** | Pull-only. You cannot push images through this path. |
| **SaaS/registry down** | **Running ERP is unaffected.** Only a new pull you explicitly requested would fail until service returns. |

Nothing in the pull flow uploads your business database or filestore.

## New instance install (`--new`) — Phase 8

When you run `soviez.sh --new`, Soviez connects to Cloud for steps **you start** by running the command:

| Step | What is sent | What is never sent |
|------|--------------|-------------------|
| Consent | — (disclosure only) | — |
| Device authorization | Public key, fingerprint, optional label | Private key, business data |
| License Slot reservation | Operation id, activation method choice | Activation key |
| Image pull | Digest, release id, device PoP | Docker Hub org token, business data |
| License issue | Fingerprint (after bind) | Business DB / filestore |
| Activation ack (automatic) | Slot id, success signal | Activation key |

**Automatic activation:** the key is stored locally at `0600` and passed to the official ORM method inside your container. It never appears in logs or command arguments.

**Manual activation:** no ORM call; you activate via the portal later.

**Disconnect:** use `--reattach <operation-id>` to resume; no duplicate slot consumption.

**SaaS down mid-install:** resume when service returns; running ERP (if already activated) unaffected.

## Never sent

Accounting data, customer lists, attachments, database dumps, filestore files, passwords, activation keys, device private keys, Docker Hub organization tokens.
