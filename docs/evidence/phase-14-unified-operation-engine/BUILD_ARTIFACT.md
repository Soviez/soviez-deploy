# Build Artifact Verification

**Phase:** 14  
**Verdict:** PASS  
**Version:** `0.14.0-phase14`  

## 1. Artifact Verification

The compiled executable `dist/soviez.sh` matches the build specifications:

- **Distributable Path:** `dist/soviez.sh`
- **Distributable SHA256:** `f6c8a81095012bf20b8bc1fdf70cac981a0c7657abd5f1885871f6983188f69d`
- **Verification Method:** Verified using local `shasum` checks matching `dist/soviez.sh.sha256`.

## 2. Integrated Modules
The assembled executable safely includes all `src/ops/*.sh` libraries, ensuring zero dependency on loose local shell files in client deployment sandboxes.
