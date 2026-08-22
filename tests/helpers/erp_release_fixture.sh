#!/usr/bin/env bash
# shellcheck shell=bash
# Canonical certification ERP image resolution via share/releases/catalog.json.
# Tests must not hardcode soviez/erp:p15-* or :latest as deployment authority.

soviez_test_erp_catalog_path() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s/share/releases/catalog.json\n' "$root"
}

# Resolve release metadata. Sets SOVIEZ_TEST_ERP_RELEASE, REPO, DIGEST, IMAGE_REF.
soviez_test_erp_release_resolve() {
  local release="${1:-${SOVIEZ_TEST_CERT_RELEASE:-cert-0.24.6.4}}"
  local catalog
  catalog="$(soviez_test_erp_catalog_path)"
  [[ -f "$catalog" ]] || { echo "[erp-fixture] FAIL: missing catalog $catalog" >&2; return 1; }
  local meta
  meta="$(python3 - "$catalog" "$release" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1], encoding="utf-8"))
name = sys.argv[2]
repo = cat.get("repository", "")
for r in cat.get("releases", []):
    if r.get("release_name") == name or r.get("release_id") == name:
        print(json.dumps({
            "release": name,
            "repository": repo or r.get("repository", ""),
            "digest": r.get("image_digest", ""),
            "image_ref": r.get("image_ref", ""),
        }))
        sys.exit(0)
sys.exit(1)
PY
)" || { echo "[erp-fixture] FAIL: release not in catalog: $release" >&2; return 1; }
  SOVIEZ_TEST_ERP_RELEASE="$release"
  SOVIEZ_TEST_ERP_REPO="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["repository"])' "$meta")"
  SOVIEZ_TEST_ERP_DIGEST="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["digest"])' "$meta")"
  SOVIEZ_TEST_ERP_IMAGE_REF="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["image_ref"])' "$meta")"
  export SOVIEZ_TEST_ERP_RELEASE SOVIEZ_TEST_ERP_REPO SOVIEZ_TEST_ERP_DIGEST SOVIEZ_TEST_ERP_IMAGE_REF
  return 0
}

soviez_test_erp_pull_cert_release() {
  soviez_test_erp_release_resolve "${1:-}" || return 1
  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
  docker pull "${SOVIEZ_TEST_ERP_IMAGE_REF}" >/dev/null 2>&1 || {
    echo "[erp-fixture] FAIL: docker pull ${SOVIEZ_TEST_ERP_IMAGE_REF}" >&2
    return 1
  }
  echo "[erp-fixture] pulled ${SOVIEZ_TEST_ERP_IMAGE_REF}"
  return 0
}

# Stable local tags for multi-digest update/restore suites (not p15-*).
soviez_test_erp_fixture_tag_current() { printf '%s\n' "${SOVIEZ_TEST_ERP_TAG_CURRENT:-soviez-test/cert-current}"; }
soviez_test_erp_fixture_tag_prior() { printf '%s\n' "${SOVIEZ_TEST_ERP_TAG_PRIOR:-soviez-test/cert-prior}"; }
soviez_test_erp_fixture_tag_legacy() { printf '%s\n' "${SOVIEZ_TEST_ERP_TAG_LEGACY:-soviez-test/cert-legacy}"; }

# Ensure current (catalog digest) + distinct prior + legacy fixture tags exist.
soviez_test_erp_fixture_tags_ensure() {
  soviez_test_erp_release_resolve "${1:-}" || return 1
  soviez_test_erp_pull_cert_release "${SOVIEZ_TEST_ERP_RELEASE}" || return 1

  local tag_cur tag_prior tag_legacy id_cur id_prior id_legacy
  tag_cur="$(soviez_test_erp_fixture_tag_current)"
  tag_prior="$(soviez_test_erp_fixture_tag_prior)"
  tag_legacy="$(soviez_test_erp_fixture_tag_legacy)"

  docker tag "${SOVIEZ_TEST_ERP_IMAGE_REF}" "$tag_cur"
  id_cur="$(docker image inspect "$tag_cur" --format '{{.Id}}')"

  id_prior="$(docker image inspect "$tag_prior" --format '{{.Id}}' 2>/dev/null || true)"
  id_legacy="$(docker image inspect "$tag_legacy" --format '{{.Id}}' 2>/dev/null || true)"

  if [[ -z "$id_prior" || "$id_prior" == "$id_cur" ]]; then
    local cid
    cid="$(docker create "${SOVIEZ_TEST_ERP_IMAGE_REF}")"
    docker commit \
      --change 'LABEL com.soviez.managed=true' \
      --change 'LABEL com.soviez.product=erp' \
      --change 'LABEL com.soviez.fixture-variant=prior' \
      --change "LABEL com.soviez.release-id=${SOVIEZ_TEST_ERP_RELEASE}-prior" \
      "$cid" "$tag_prior" >/dev/null
    docker rm "$cid" >/dev/null
    id_prior="$(docker image inspect "$tag_prior" --format '{{.Id}}')"
  fi

  if [[ -z "$id_legacy" || "$id_legacy" == "$id_cur" || "$id_legacy" == "$id_prior" ]]; then
    local cid2
    cid2="$(docker create "$tag_prior")"
    docker commit \
      --change 'LABEL com.soviez.managed=true' \
      --change 'LABEL com.soviez.product=erp' \
      --change 'LABEL com.soviez.fixture-variant=legacy' \
      --change "LABEL com.soviez.release-id=${SOVIEZ_TEST_ERP_RELEASE}-legacy" \
      "$cid2" "$tag_legacy" >/dev/null
    docker rm "$cid2" >/dev/null
    id_legacy="$(docker image inspect "$tag_legacy" --format '{{.Id}}')"
  fi

  if [[ "$id_cur" == "$id_prior" || "$id_cur" == "$id_legacy" || "$id_prior" == "$id_legacy" ]]; then
    echo "[erp-fixture] FAIL: fixture tags not distinct" >&2
    return 1
  fi

  export SOVIEZ_TEST_ERP_CURRENT_IMAGE="$tag_cur"
  export SOVIEZ_TEST_ERP_PRIOR_IMAGE="$tag_prior"
  export SOVIEZ_TEST_ERP_LEGACY_IMAGE="$tag_legacy"
  echo "[erp-fixture] tags current=$tag_cur prior=$tag_prior legacy=$tag_legacy (catalog ${SOVIEZ_TEST_ERP_RELEASE})"
  return 0
}
