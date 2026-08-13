# DNS_AUTHORITATIVE_VALIDATION

`src/migration/dns/authoritative.sh` + CoreDNS authoritative container in e2e (`coredns/coredns:1.11.3`).

Queries run on the Docker network (not host-published UDP) because Colima host UDP publish is unreliable.

Mock fixture provider writes authoritative zone views for unit tests.
