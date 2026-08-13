#!/usr/bin/env bash
set -euo pipefail

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  if [[ "$expected" != "$actual" ]]; then
    echo "ASSERT_EQ failed: expected='$expected' actual='$actual' ${msg}" >&2
    return 1
  fi
}

assert_ne() {
  local a="$1"
  local b="$2"
  local msg="${3:-}"
  if [[ "$a" == "$b" ]]; then
    echo "ASSERT_NE failed: '$a' == '$b' ${msg}" >&2
    return 1
  fi
}

assert_ok() {
  local msg="${1:-command failed}"
  if [[ $? -ne 0 ]]; then
    echo "ASSERT_OK failed: $msg" >&2
    return 1
  fi
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || { echo "Missing file: $path" >&2; return 1; }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s' "$haystack" | grep -Fq "$needle"; then
    echo "Forbidden substring found: $needle" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -Fq "$needle" || {
    echo "Expected substring not found: $needle" >&2
    return 1
  }
}
