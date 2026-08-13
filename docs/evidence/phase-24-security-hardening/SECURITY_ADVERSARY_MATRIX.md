# Security adversary matrix

| Adversary | Result |
|-----------|--------|
| Unsigned update | DENIED |
| Fake fixture signature on Production | DENIED |
| Checksum-only authorization | DENIED |
| Fixture token on Production | DENIED |
| Ticket replay second consume | DENIED |
| Registry purpose as update auth | DENIED |
| Persist Docker auth | DENIED / FAIL cert |
| Embed service-role in dist | DENIED (scan) |
