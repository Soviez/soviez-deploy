# Certified Artifact

```text
Version:
0.24.5.3-registry-gateway
SHA256:
68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460
Engineering:
100%
Security Platform:
CERTIFIED
Release:
NOT AUTHORIZED
```

## Provenance

- Prior: `0.24.5.1-security-s5-corr1` / `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (S6 + Phase 25)
- Post-cert corrective: `0.24.5.3-registry-gateway` closes Stage proxy_mode, Phase-12 WS, P21 upstream, workers topology enforcement

## Verify

```bash
sha256sum dist/soviez.sh
# must equal 68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460
```
