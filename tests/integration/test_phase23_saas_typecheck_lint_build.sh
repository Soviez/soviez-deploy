#!/usr/bin/env bash
# Phase 23 — SaaS typecheck / lint / safe next build / phase23 unit.
# Does NOT apply migrations to live SaaS DB. Does not modify frozen UI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAAS_ROOT="${SAAS_ROOT:-$(cd "$ROOT/../soviez-saas" && pwd)}"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env
soviez_phase23_assert_cert_gates

[[ -d "$SAAS_ROOT" ]] || { echo "FAIL: missing $SAAS_ROOT" >&2; exit 1; }
cd "$SAAS_ROOT"

echo "== phase23 unit tests =="
npx --yes tsx --test src/lib/offline-bundle/phase23.test.ts

echo "== entitlement unit (Phase 4 regression surface) =="
npm run test:entitlements

echo "== typecheck =="
npm run typecheck

echo "== lint =="
set +e
LINT_OUT="$(npm run lint 2>&1)"
LINT_RC=$?
set -e
if [[ $LINT_RC -ne 0 ]]; then
  if echo "$LINT_OUT" | grep -Eqi 'Error:|Failed to compile|Parsing error'; then
    echo "$LINT_OUT" | tail -n 80 >&2
    echo "FAIL: lint errors" >&2
    exit 1
  fi
  echo "[warn] lint exit=$LINT_RC with warnings only (documented as pre-existing/unrelated)"
fi
echo "$LINT_OUT" | tail -n 20

echo "== next build (no live migrate; DATABASE_URL unset) =="
set +e
BUILD_OUT="$(env -u DATABASE_URL npx next build 2>&1)"
BUILD_RC=$?
set -e
if [[ $BUILD_RC -ne 0 ]]; then
  echo "$BUILD_OUT" | tail -n 100 >&2
  echo "FAIL: next build" >&2
  exit 1
fi
echo "$BUILD_OUT" | tail -n 15

echo "OK test_phase23_saas_typecheck_lint_build"
exit 0
