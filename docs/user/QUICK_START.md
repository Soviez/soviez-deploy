# Quick Start

**Version:** `0.24.5.3-registry-gateway`

## 1. Bootstrap host (Production wizard)

On a clean Ubuntu 22.04/24.04 amd64 server:

```bash
sudo soviez.sh --init
```

Use the supported dual wizard from `Soviez ERP/soviez.sh` or byte-identical `soviez-deploy/soviez.sh`.

## 2. Create Production

```bash
sudo soviez.sh --new
```

Follow prompts for domain, activation, and channel. Automatic activation is the default when connected.

## 3. Verify edge

- DNS A/AAAA (or Cloudflare) points to the server
- HTTPS on `:443` serves ERP via Nginx
- Do **not** open `:8069` publicly

## 4. Modular operations (certified artifact)

```bash
# From modular installer
soviez.sh --help
soviez.sh --security-status
soviez.sh --backup <production-id>
soviez.sh --operations
```

Artifact: `0.24.5.3-registry-gateway` · SHA256 `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`

## 5. Create a Stage (when entitled)

```bash
soviez.sh --stage --production-tenant <id> --stage-domain stage.example.com
```

## Next

- [INSTALLATION.md](INSTALLATION.md)
- [CLI_REFERENCE.md](CLI_REFERENCE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
