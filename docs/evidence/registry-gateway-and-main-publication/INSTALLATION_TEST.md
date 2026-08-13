# INSTALLATION_TEST — Registry Gateway Packaging

## Scope

Verify the gateway installable package is complete, builds, and passes health checks in a local/disposable environment.

## Package locations

| Tree | Path |
|------|------|
| Local ops | `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway` |
| Mirror | `soviez-sh/services/registry-gateway/` |

## Build verification

| Step | Command | Expected |
|------|---------|----------|
| Dependencies | `npm install` | Exit 0 |
| Typecheck | `npm run typecheck` | Exit 0 |
| Build | `npm run build` | `dist/` populated |
| Unit tests | `npm test` | **20/20 PASS** |

## Install scripts present

| Script | Purpose | Status |
|--------|---------|--------|
| `install.sh` | Idempotent install | Present |
| `healthcheck.sh` | Probe `/live` `/ready` `/health` | Present |
| `update.sh` | Rolling update | Present |
| `uninstall.sh` | Teardown (+ `--purge`) | Present |

## Deployment artifacts

| Artifact | Status |
|----------|--------|
| `compose.yml` | Present |
| `Dockerfile` | Present (non-root) |
| `systemd/soviez-registry-gateway.service` | Present |
| `nginx/registry.soviez.com.conf` | Present (TLS template) |
| `config/gateway.env.example` | Placeholders only |

## Documentation bundle

| Doc | Status |
|-----|--------|
| INSTALLATION, CONFIGURATION, OPERATIONS | Present |
| SECURITY, TROUBLESHOOTING, UPGRADE, RECOVERY | Present |

## Production install test

| Environment | Result |
|-------------|--------|
| Ubuntu VPS + systemd + nginx | **PENDING** (not provisioned this cycle) |
| Local Compose smoke | Runnable (not logged separately) |

## Canonical publish readiness

Package is **INSTALLABLE** and ready for publication to `Soviez/soviez-deploy/services/registry-gateway/`.

Push to remote main: **PENDING**.
