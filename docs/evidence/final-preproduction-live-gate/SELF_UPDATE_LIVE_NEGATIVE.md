# SELF_UPDATE_LIVE_NEGATIVE

- captured_utc: 2026-08-16T16:20:38Z
- host: soviez-u2404
- Method:  with  + 

| Case | Result | Notes |
|---|---|---|
| SELFUP-LIVE-02 invalid signature | PASS (fail-closed) | Ed25519 verification failed; payload unchanged |
| SELFUP-LIVE-03 wrong SHA field | PASS (fail-closed) | SHA256 mismatch; payload unchanged |
| SELFUP-LIVE-04 unknown signer | PASS (fail-closed) | no trusted public key for signer_key_id |
| SELFUP-LIVE-05 malformed manifest | PASS (fail-closed) | malformed release manifest |
| SELFUP-LIVE-10 executable survives | PASS | launcher + payload remain executable |

Side note: Ubuntu  emits  during some verify paths (version_cmp  mishandled) but fail-closed still held.
