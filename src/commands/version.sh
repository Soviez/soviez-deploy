# shellcheck shell=bash

soviez_cmd_version_run() {
  local ver channel digest payload
  ver="$(soviez_version)"
  channel="$(soviez_platform_channel)"
  if [[ -f "$(soviez_platform_current_dir)/CHANNEL" ]]; then
    channel="$(tr -d '[:space:]' <"$(soviez_platform_current_dir)/CHANNEL")"
  fi
  digest="$(soviez_platform_installed_digest)"
  payload="$(soviez_platform_payload)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    payload="${SOVIEZ_ROOT}/platform/current/soviez.sh"
    if [[ -f "${SOVIEZ_ROOT}/platform/current/CHANNEL" ]]; then
      channel="$(tr -d '[:space:]' <"${SOVIEZ_ROOT}/platform/current/CHANNEL")"
    fi
    if [[ -f "${SOVIEZ_ROOT}/platform/current/soviez.sh.sha256" ]]; then
      digest="$(awk 'NR==1{print $1}' "${SOVIEZ_ROOT}/platform/current/soviez.sh.sha256")"
    fi
  fi
  cat <<EOF
Soviez.sh ${ver}
Channel: ${channel}
Artifact: sha256:${digest}
Payload: ${payload}
EOF
}
