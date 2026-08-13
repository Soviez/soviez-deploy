# Firewall & Docker networking (S2)

Soviez detects the active backend (`ufw`, `firewalld`, `nftables`, `iptables`, or `none`) and applies additive Soviez-owned rules. Production paths never `iptables -F`, `nft flush ruleset`, `ufw reset`, or `firewall-cmd --complete-reload`.

Default ingress: deny unsolicited; allow SSH (management port), 80, 443. Outbound allowed. Docker `DOCKER-USER` drops published 8069/8071/8072/5432 from non-loopback paths without disabling Docker iptables integration.
