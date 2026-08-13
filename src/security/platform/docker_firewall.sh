# shellcheck shell=bash
# Security Gate S2 — iptables additive helpers + DOCKER-USER (never iptables -F).

soviez_fw_iptables_apply() {
  local ssh_port="${1:-22}"
  if ! command -v iptables >/dev/null 2>&1; then
    return 0
  fi
  # Ensure INPUT accepts SSH/80/443 if chain is reachable (best-effort, non-flush).
  iptables -C INPUT -p tcp --dport "$ssh_port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "$ssh_port" -j ACCEPT 2>/dev/null || true
  iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
  iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
}

soviez_fw_docker_apply_user_chain() {
  # DOCKER-USER: drop unexpected published app/db ports from external interfaces.
  # Preserve Docker's own chains; never iptables -F DOCKER*.
  if ! command -v iptables >/dev/null 2>&1; then
    return 0
  fi
  iptables -L DOCKER-USER -n >/dev/null 2>&1 || \
    iptables -N DOCKER-USER 2>/dev/null || true
  # Return early for established.
  iptables -C DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN 2>/dev/null || \
    iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN 2>/dev/null || true
  # Allow loopback / docker bridge source free (conservative).
  iptables -C DOCKER-USER -i lo -j RETURN 2>/dev/null || \
    iptables -I DOCKER-USER -i lo -j RETURN 2>/dev/null || true
  local p
  for p in 8069 8071 8072 5432; do
    # Drop NEW connections to published container ports from non-loopback.
    iptables -C DOCKER-USER -p tcp --dport "$p" -j DROP 2>/dev/null || \
      iptables -A DOCKER-USER -p tcp --dport "$p" -m comment --comment "SOVIEZ_S2_BLOCK_${p}" -j DROP 2>/dev/null || true
  done
  iptables -C DOCKER-USER -j RETURN 2>/dev/null || \
    iptables -A DOCKER-USER -j RETURN 2>/dev/null || true
  return 0
}

soviez_fw_docker_forwarding_healthy() {
  # Soft check: docker can create a network / DOCKER chains exist OR docker uses nft.
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker absent"
    return 1
  fi
  docker info >/dev/null 2>&1 || return 1
  return 0
}
