# NO_NETWORK_ATTEMPTS

Captured during air-gapped apply certification:
```text
network_required_during_apply=false
unexpected_network_attempts=0
```
Mechanism: `soviez_phase23_assert_no_network_hooks` sets deny proxies; apply writes `network_proof.txt` under the operation directory.
