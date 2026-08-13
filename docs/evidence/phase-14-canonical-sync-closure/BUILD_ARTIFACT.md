# Build Artifact Verification

This document records the details and cryptographic verification of the built installer artifact for Phase 14.

## 1. Artifact Details

- **File Path:** `dist/soviez.sh`
- **Version:** `0.14.0-phase14`
- **Schema Version:** `1`
- **Build Script:** `build/assemble.sh`

## 2. Cryptographic Verification

The built artifact has been cryptographically hashed to ensure integrity and prevent tampering:

- **Hash Algorithm:** SHA-256
- **Hash Source File:** `dist/soviez.sh.sha256`
- **Recorded SHA-256 Hash:** `f0c2ef503b434ffcf640496e6e77cbe96b948c0d65e1605dd011b99c96159d62`

## 3. Integrity Verification

The hash recorded in `dist/soviez.sh.sha256` matches the SHA-256 hash of the built `dist/soviez.sh` file exactly. This confirms that the artifact is complete, uncorrupted, and ready for deployment when authorized.
