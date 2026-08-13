#!/usr/bin/env bash
# Phase 22 G1 — SaaS typecheck/lint/build (+ disposable PG proofs via certification runner).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
chmod +x "$ROOT/scripts/phase22-saas-certification.sh" 2>/dev/null || true
bash "$ROOT/scripts/phase22-saas-certification.sh"
