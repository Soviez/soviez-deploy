#!/usr/bin/env bash
# shellcheck shell=bash
# Detect source/artifact mutation during tests/run_all (moving-tree contamination).

soviez_frozen_tree_guard_start() {
  local root="${SOVIEZ_SH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  export SOVIEZ_FROZEN_GUARD_ROOT="$root"
  export SOVIEZ_FROZEN_GUARD_HEAD="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
  export SOVIEZ_FROZEN_GUARD_STATUS_HASH="$(git -C "$root" status --porcelain 2>/dev/null | shasum -a 256 | awk '{print $1}')"
  export SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA=""
  if [[ -f "$root/dist/soviez.sh" ]]; then
    SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA="$(shasum -a 256 "$root/dist/soviez.sh" | awk '{print $1}')"
  fi
  export SOVIEZ_FROZEN_GUARD_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$root/docs/evidence/freeze-reconcile-0.24.6.4" 2>/dev/null || true
  {
    echo "timestamp=$SOVIEZ_FROZEN_GUARD_TS"
    echo "head=$SOVIEZ_FROZEN_GUARD_HEAD"
    echo "status_hash=$SOVIEZ_FROZEN_GUARD_STATUS_HASH"
    echo "artifact_sha=$SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA"
  } > "${SOVIEZ_FROZEN_GUARD_RECORD:-$root/docs/evidence/freeze-reconcile-0.24.6.4/FROZEN_TREE_GUARD_START.txt}"
}

soviez_frozen_tree_guard_verify() {
  local root="${SOVIEZ_FROZEN_GUARD_ROOT:-}"
  [[ -n "$root" ]] || return 0
  local head_now status_now artifact_now
  head_now="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
  status_now="$(git -C "$root" status --porcelain 2>/dev/null | shasum -a 256 | awk '{print $1}')"
  artifact_now=""
  [[ -f "$root/dist/soviez.sh" ]] && artifact_now="$(shasum -a 256 "$root/dist/soviez.sh" | awk '{print $1}')"
  if [[ "$head_now" != "${SOVIEZ_FROZEN_GUARD_HEAD:-}" ]]; then
    echo "TEST_INVALID_MOVING_TREE: HEAD changed ${SOVIEZ_FROZEN_GUARD_HEAD:-} -> $head_now" >&2
    return 1
  fi
  if [[ "$status_now" != "${SOVIEZ_FROZEN_GUARD_STATUS_HASH:-}" ]]; then
    echo "TEST_INVALID_MOVING_TREE: working tree changed during run" >&2
    return 1
  fi
  if [[ -n "${SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA:-}" && "$artifact_now" != "$SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA" ]]; then
    echo "TEST_INVALID_MOVING_TREE: dist/soviez.sh SHA changed ${SOVIEZ_FROZEN_GUARD_ARTIFACT_SHA} -> $artifact_now" >&2
    return 1
  fi
  return 0
}
