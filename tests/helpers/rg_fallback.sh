#!/usr/bin/env bash
# Provide `rg` when ripgrep is not installed (grep -R fallback). Bash 3.2 compatible.
if ! type -P rg >/dev/null 2>&1; then
  rg() {
    local pat="" glob="" arg
    local path_list=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -n|--color=never|--no-heading|--with-filename) shift ;;
        --glob|-g) glob="$2"; shift 2 ;;
        -e) pat="$2"; shift 2 ;;
        -l) shift ;;
        -*) shift ;;
        *)
          if [[ -z "$pat" ]]; then
            pat="$1"
          else
            path_list="${path_list}"$'\n'"$1"
          fi
          shift
          ;;
      esac
    done
    [[ -n "$pat" ]] || return 1
    [[ -n "$path_list" ]] || return 1
    local p any=1 out
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      out=""
      if [[ -d "$p" ]]; then
        if [[ -n "$glob" ]]; then
          out="$(grep -RInE --include="$glob" -e "$pat" "$p" 2>/dev/null || true)"
        else
          out="$(grep -RInE -e "$pat" "$p" 2>/dev/null || true)"
        fi
      elif [[ -f "$p" ]]; then
        out="$(grep -nE -e "$pat" "$p" 2>/dev/null || true)"
      fi
      if [[ -n "$out" ]]; then
        printf '%s\n' "$out"
        any=0
      fi
    done <<< "$path_list"
    return $any
  }
fi
