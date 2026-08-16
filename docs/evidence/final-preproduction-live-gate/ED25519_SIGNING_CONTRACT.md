# ED25519_SIGNING_CONTRACT

- schema: 
- signature_algorithm: 
- canonical payload: JSON object with keys , , ,  removed; , UTF-8, no trailing newline
- signature encoding: raw 64-byte Ed25519, base64url without padding
- verify: OpenSSL 
- candidate must match manifest e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 and embedded version must match manifest 
- channel staging manifest URL (cert branch): https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.1-platform-cli/platform-release/staging/manifest.json
