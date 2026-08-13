# shellcheck shell=bash

soviez_ui_consent_prompt() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" || "${SOVIEZ_AUTO_CONSENT:-0}" == "1" ]]; then
    soviez_log_info "Connection consent auto-approved (test mode)"
    return 0
  fi
  soviez_log_info "Soviez needs your consent to connect online for license reservation."
  read -r -p "Allow connection? [y/N] " ans
  case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) soviez_die "$SOVIEZ_ERR_GENERIC" "Connection consent denied" ;;
  esac
}
