#!/usr/bin/env bash
set +e
NEG_PASS=0
NEG_FAIL=0
probe_neg() {
  name="$1"
  man="$2"
  out=$(bash -c 'source /opt/soviez/platform/current/soviez.sh; soviez_platform_verify_candidate /tmp/soviez-0.24.6.2.sh "'"$man"'"' 2>&1)
  rc=$?
  echo "NEG_$name rc=$rc"
  echo "$out" | head -3
  if [[ $rc -ne 0 ]]; then
    NEG_PASS=$((NEG_PASS + 1))
    echo "NEG_$name=PASS_FAIL_CLOSED"
  else
    NEG_FAIL=$((NEG_FAIL + 1))
    echo "NEG_$name=UNEXPECTED_ACCEPT"
  fi
}
probe_neg BADSIG /tmp/manifest-badsig.json
probe_neg BADSHA /tmp/manifest-wrong-sha.json
probe_neg BADKEY /tmp/manifest-unknown-signer.json
probe_neg MALFORMED /tmp/manifest-malformed.json
echo "NEG_SUMMARY pass_closed=$NEG_PASS unexpected=$NEG_FAIL"
