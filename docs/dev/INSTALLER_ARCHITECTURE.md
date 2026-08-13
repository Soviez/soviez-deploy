# Installer Architecture

## Certified modular artifact

- Build: `build/assemble.sh`
- Output: `dist/soviez.sh`
- Version file: `VERSION` → `0.24.5.1-security-s5-corr1`
- SHA256: `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`

Docs-only changes must **not** regenerate dist unless product src changes.

## Dual wizard

`Soviez ERP/soviez.sh` and `soviez-deploy/soviez.sh` remain supported for `--init`/`--new` and must stay APT-lock safe (wait-or-fail).
