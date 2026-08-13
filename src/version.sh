# shellcheck shell=bash
SOVIEZ_VERSION="${SOVIEZ_VERSION:-}"

soviez_version() {
  if [[ -n "${SOVIEZ_VERSION:-}" ]]; then
    printf '%s\n' "$SOVIEZ_VERSION"
    return 0
  fi
  # Embedded at build time via assemble.sh header comment.
  if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    local line
    line="$(grep -m1 '^# version:' "${BASH_SOURCE[0]}" 2>/dev/null || true)"
    if [[ "$line" =~ version:[[:space:]]*(.+) ]]; then
      SOVIEZ_VERSION="${BASH_REMATCH[1]}"
      SOVIEZ_VERSION="${SOVIEZ_VERSION// /}"
      printf '%s\n' "$SOVIEZ_VERSION"
      return 0
    fi
  fi
  if [[ -f "${SOVIEZ_SH_ROOT:-}/VERSION" ]]; then
    SOVIEZ_VERSION="$(tr -d '[:space:]' < "${SOVIEZ_SH_ROOT}/VERSION")"
    printf '%s\n' "$SOVIEZ_VERSION"
    return 0
  fi
  printf '%s\n' "unknown"
}
