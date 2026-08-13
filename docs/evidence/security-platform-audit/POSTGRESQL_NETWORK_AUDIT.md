# PostgreSQL network audit

Production DB container: `--network ${NETWORK_NAME}` only — **no `-p`**.

```text
Host-public PostgreSQL port publish = ABSENT in production installer
Binding 0.0.0.0:5432 via docker publish = NOT observed
```

Residual risks: host-installed postgres elsewhere; operator manual publish; compromise of peer containers on same bridge.

Desired future: keep no host-public PG; optional further segmentation (ERP↔PG private network only).
