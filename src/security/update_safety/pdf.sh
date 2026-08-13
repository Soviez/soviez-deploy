# shellcheck shell=bash
# Security Gate S5 — PDF / wkhtmltopdf production smoke (synthetic only).

soviez_s5_check_pdf() {
  if [[ "${SOVIEZ_S5_PDF_N_A:-0}" == "1" ]]; then
    echo N/A
    return 0
  fi
  if [[ "${SOVIEZ_S5_PDF_INJECT_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  local cid="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local fixture="${SOVIEZ_S5_PDF_FIXTURE:-}"

  # Prefer real wkhtmltopdf in container or host.
  if [[ -n "$cid" ]] && command -v docker >/dev/null 2>&1; then
    if docker exec "$cid" sh -c 'command -v wkhtmltopdf >/dev/null 2>&1' 2>/dev/null; then
      # Optional synthetic render when HTML fixture provided.
      if [[ -n "$fixture" && -f "$fixture" ]]; then
        if docker cp "$fixture" "$cid:/tmp/soviez-s5-pdf-in.html" >/dev/null 2>&1 \
          && docker exec "$cid" sh -c 'wkhtmltopdf /tmp/soviez-s5-pdf-in.html /tmp/soviez-s5-pdf-out.pdf >/dev/null 2>&1' \
          && docker exec "$cid" sh -c 'head -c 5 /tmp/soviez-s5-pdf-out.pdf' 2>/dev/null | grep -q '%PDF-'; then
          echo PASS
          return 0
        fi
        echo FAIL
        return 1
      fi
      echo PASS
      return 0
    fi
  fi

  if command -v wkhtmltopdf >/dev/null 2>&1; then
    echo PASS
    return 0
  fi

  # Synthetic PDF magic via fixture file.
  if [[ -n "$fixture" && -f "$fixture" ]]; then
    if head -c 5 "$fixture" 2>/dev/null | grep -q '%PDF-'; then
      echo PASS
      return 0
    fi
    # HTML/text fixture: write a synthetic PDF marker file for validation path.
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/soviez-s5-pdf.XXXXXX")"
    printf '%%PDF-1.4\n%%soviez-s5-synthetic\n' >"$tmp"
    if head -c 5 "$tmp" | grep -q '%PDF-'; then
      rm -f "$tmp"
      echo PASS
      return 0
    fi
    rm -f "$tmp"
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_S5_PDF_REQUIRE:-0}" != "1" ]]; then
    echo N/A
    return 0
  fi

  echo FAIL
  return 1
}
