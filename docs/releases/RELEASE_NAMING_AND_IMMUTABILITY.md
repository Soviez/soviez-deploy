# Release naming and immutability

See [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §6.

## Concepts

| Term | Description |
|------|-------------|
| **Release name** | Owner-defined product label (`Sam0.1`, `Sam0.2`, …) |
| **Internal platform build** | Soviez.sh semver family (`0.24.6.3-platform-cli`) |
| **Channel** | `stable`, `certification`, `preview` |
| **Digest** | Immutable `sha256:…` deployment identity |

## Immutability rule

```text
Sam0.2 → sha256:A   (published)
```

must never become:

```text
Sam0.2 → sha256:B
```

New ERP build → new release name (`Sam0.3`).

## Docker tags

Tags may aid publishing. **`latest` is not deployment authority.**

Canonical pull:

```bash
docker pull soviez/soviez-erp@sha256:<digest>
```

Resolution path: release name → signed metadata → repository + digest.

## Channel promotion

Promotion from `certification` to `stable` should not require rebuild if digest unchanged.
