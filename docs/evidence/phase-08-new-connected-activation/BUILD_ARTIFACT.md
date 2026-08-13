# BUILD_ARTIFACT — Phase 8

## Build command

```bash
cd /path/to/soviez-sh
bash build/assemble.sh
bash -n dist/soviez.sh
```

## Output

| File | Description |
|------|-------------|
| `dist/soviez.sh` | Executable assembled installer |
| `dist/soviez.sh.sha256` | SHA256 checksum of assembled file |

## Version

From `VERSION` file: **`0.8.0-phase8`**

## Checksum (certification session)

```
34ab9413ae86d2b66adcdeed0ea16c9e92c4a1485bd8c15528c939c9d06fabb2
```

**Note:** SHA256 changes on every rebuild. Always refer to `dist/soviez.sh.sha256` for the current value.

## Validation

| Check | Result |
|-------|--------|
| `bash -n dist/soviez.sh` | **PASS** |
| ShellCheck | **UNAVAILABLE** on certification host |
| `tests/run_all.sh` (includes assemble) | **PASS** |

## Module count

36 source modules → 1 distributable script.

## Edit policy

Source of truth: `src/**`  
Generated: `dist/soviez.sh` — regenerate with `build/assemble.sh` after any `src/` change.
