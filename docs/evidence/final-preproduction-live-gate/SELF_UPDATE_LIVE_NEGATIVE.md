# SELF_UPDATE_LIVE_NEGATIVE

- captured_utc: 2026-08-16T16:20:00Z
- host: soviez-u2404
- platform under test: 0.24.6.2-platform-cli

| Case | Result |
|---|---|
| SELFUP-LIVE-02 invalid signature | PASS fail-closed |
| SELFUP-LIVE-03 wrong SHA | PASS fail-closed |
| SELFUP-LIVE-04 unknown signer | PASS fail-closed |
| SELFUP-LIVE-05 malformed manifest | PASS fail-closed |

- raw: `SELF_UPDATE_LIVE_NEGATIVE_RERUN.txt`
- NEG_SUMMARY pass_closed=4 unexpected=0
