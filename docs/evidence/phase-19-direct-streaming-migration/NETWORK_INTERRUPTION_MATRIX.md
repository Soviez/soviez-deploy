# NETWORK_INTERRUPTION_MATRIX.md

Suite: `tests/integration/test_phase19_network_interruption_matrix.sh`

Exercises real mTLS channel disruption (drop mid-chunk, lost ACK, duplicate/replay, unreachability, resume).  
Authoritative run: **PASS**. Skip forbidden in certification mode.
