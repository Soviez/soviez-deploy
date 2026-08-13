# Activation

**Version:** `0.24.5.1-security-s5-corr1`

## Modes

| Mode | When |
|------|------|
| Automatic | Default for connected `--new` |
| Manual | Operator supplies activation materials |
| Offline | Signed offline packages (no live SaaS) |

## Bindings

Activation binds **exact**:

- License
- Device
- Production slot

Invalid License, Device, or slot conflict → activation fails closed. ERP is not left in an ambiguous half-activated Production without Needs Action / recovery paths.

## SaaS unavailable

If SaaS is down during activation, connected activation cannot complete. **Already-running ERP continues** — activation is not a continuous runtime dependency.

## Modular commands

```bash
./dist/soviez.sh --new [--activation automatic|manual] [--domain FQDN]
./dist/soviez.sh --reattach <operation-id>
```
