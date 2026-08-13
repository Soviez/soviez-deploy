#!/usr/bin/env bash
# Phase 22 G1 — SaaS schema upgrade proof (disposable Postgres only).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAAS_ROOT="${SAAS_ROOT:-$(cd "$ROOT/../soviez-saas" && pwd)}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
[[ -d "$SAAS_ROOT" ]] || { echo "soviez-saas not found at $SAAS_ROOT" >&2; exit 1; }
chmod +x "$SAAS_ROOT/scripts/phase22-schema-upgrade-proof.sh" 2>/dev/null || true
bash "$SAAS_ROOT/scripts/phase22-schema-upgrade-proof.sh"
