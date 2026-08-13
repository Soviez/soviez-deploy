# shellcheck shell=bash
# Security Gate S2 — nftables backend (additive table only; never nft flush ruleset).

soviez_fw_nft_apply() {
  local ssh_port="${1:-22}"
  if ! command -v nft >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: nft missing" >&2
    return 1
  fi
  # Additive Soviez-owned table/chain — do not flush global ruleset.
  nft list table inet soviez_s2 >/dev/null 2>&1 || \
    nft add table inet soviez_s2 2>/dev/null || true
  nft list chain inet soviez_s2 input >/dev/null 2>&1 || \
    nft add chain inet soviez_s2 input '{ type filter hook input priority 0; policy accept; }' 2>/dev/null || true
  # Allow established + SSH/80/443 (idempotent add may fail if exists — ignore).
  nft add rule inet soviez_s2 input ct state established,related accept 2>/dev/null || true
  nft add rule inet soviez_s2 input tcp dport "${ssh_port}" accept 2>/dev/null || true
  nft add rule inet soviez_s2 input tcp dport 80 accept 2>/dev/null || true
  nft add rule inet soviez_s2 input tcp dport 443 accept 2>/dev/null || true
  return 0
}
