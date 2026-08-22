# Quick Start

**Platform build:** `0.24.6.3-platform-cli`  
**Contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md)

## 1. Install Soviez.sh

On a clean Ubuntu 22.04/24.04 amd64 server:

```bash
curl -sSL https://soviez.sh | sudo bash
```

This installs `/usr/local/bin/soviez.sh`. Works from any directory.

## 2. Prepare the host (`--init`)

```bash
sudo soviez.sh --init
```

Prepares Docker, Nginx, firewall, security baseline, and platform layout.

> **Implementation note:** `--init` is **live-certified today** via the dual Production wizard path during PATH CLI convergence. After bootstrap install, use the `soviez.sh` on PATH. See [INITIALIZATION.md](INITIALIZATION.md).

## 3. Create Production

```bash
sudo soviez.sh --new
```

Follow prompts for domain, activation, and release channel. Connected automatic activation is the default when entitled.

## 4. Verify edge

- DNS A/AAAA points to the server
- HTTPS on `:443` serves ERP via Nginx
- Do **not** expose `:8069`, `:8072`, or `:5432` publicly

## 5. Day-2 operations

```bash
soviez.sh --help
soviez.sh --version
soviez.sh --list
soviez.sh --security-status
soviez.sh --tune --dry-run
soviez.sh --backup <production-id>
soviez.sh --operations
```

## 6. Create a Stage (when entitled)

```bash
soviez.sh --stage --production-tenant <id> --stage-domain stage.example.com
```

## Next

- [INSTALLATION.md](INSTALLATION.md)
- [CLI_REFERENCE.md](CLI_REFERENCE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
