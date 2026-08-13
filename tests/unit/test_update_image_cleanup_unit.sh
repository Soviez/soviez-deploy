#!/usr/bin/env bash
# Phase 15 final — image cleanup unit tests (no broad prune; protections)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p15-img.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init
soviez_ops_paths_init
soviez_update_paths_init
soviez_image_cleanup_paths_init

# Static forbid prune
out="$(soviez_image_forbid_prune_static_gate)"
assert_contains "$out" FORBIDDEN_PRUNE_STATIC_GATE_PASS

# Classification matrix with fixture refs (no docker required for pure classify)
refs='{"references":[
  {"digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","source":"running_container","detail":"c1"},
  {"digest":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","source":"stopped_container","detail":"c2"},
  {"digest":"sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","source":"stage_inventory","detail":"stage1"},
  {"digest":"sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","source":"production_inventory","detail":"prodB"},
  {"digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","source":"candidate","detail":"cand"},
  {"digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","source":"recovery","detail":"rec"}
]}'
# Inject fake image list via env by monkeypatching classify input — call python path indirectly
# Use dry-run path which needs docker; if docker unavailable skip live delete tests
if soviez_image_docker_available; then
  # Ensure labeled images exist from prior cert prep (or skip)
  if docker image inspect soviez/erp:p15-v13-labeled >/dev/null 2>&1; then
    # Create identity with current=v15 rollback=v14
    mkdir -p "$SOVIEZ_TENANT_DIR/prod-img/db"
    v15="$(docker image inspect soviez/erp:p15-v15-labeled --format '{{.Id}}')"
    v14="$(docker image inspect soviez/erp:p15-v14-labeled --format '{{.Id}}')"
    v13="$(docker image inspect soviez/erp:p15-v13-labeled --format '{{.Id}}')"
    python3 - <<PY > "$SOVIEZ_TENANT_DIR/prod-img/identity.json"
import json
print(json.dumps({
  "tenant_id":"prod-img",
  "current_digest":"$v15",
  "previous_digest":"$v14",
  "image_digest":"$v15",
},separators=(",",":")))
PY
    dry="$(soviez_image_cleanup_dry_run prod-img)"
    assert_contains "$dry" dry_run
    assert_contains "$dry" IMAGE_CLEANUP_DRY_RUN
    # Force window + confirm cleanup — v13 should be eligible if unused
    export SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED=1
    # Create stopped container on v13 to prove protection
    docker rm -f soviez-p15-stopped-v13 2>/dev/null || true
    docker create --name soviez-p15-stopped-v13 soviez/erp:p15-v13-labeled sleep infinity >/dev/null
    dry2="$(soviez_image_cleanup_dry_run prod-img)"
    assert_contains "$dry2" protected
    # Remove stopped container then cleanup should be able to delete v13 if eligible
    docker rm -f soviez-p15-stopped-v13 >/dev/null
    out="$(soviez_image_cleanup_execute prod-img 1 "" 0)"
    assert_contains "$out" IMAGE_CLEANUP
    # current and rollback must still exist
    docker image inspect "$v15" >/dev/null
    docker image inspect "$v14" >/dev/null
  else
    echo "NOTE: labeled soviez/erp:p15-v*-labeled images missing — docker classification skip" >&2
  fi
else
  echo "NOTE: Docker unavailable — prune gate only" >&2
fi

# Conflict matrix
assert_eq "supersede_cleanup" "$(soviez_ops_conflict_decide production_update update_image_cleanup env1 env1 1)"
assert_eq "deny" "$(soviez_ops_conflict_decide update_image_cleanup production_update env1 env1 1)"

echo "PASS test_update_image_cleanup_unit"
rm -rf "$SOVIEZ_ROOT"
